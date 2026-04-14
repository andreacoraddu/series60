classdef HullGeometry
% HullGeometry  Series 60 CB=0.60 offset grid generator and STL builder.
%
%  g = HullGeometry();          % default 1 m model
%  g = HullGeometry(Name,Val);  % override any parameter
%
%  Key properties (read-only after build):
%    xi, zi          – station / waterline vectors [m]
%    Yi              – half-breadth matrix [Nst x Nwl]
%    tris            – Ntri x 9 triangle vertex array (STL format)
%    B, T, Lpp       – principal dimensions [m]

properties (SetAccess = private)
    Lpp      = 1.0
    CB_target= 0.60
    LB       = 7.5
    BT       = 2.5
    Nst      = 120
    Nwl      = 60
    geometry_source = 'legacy_table3'

    B, T, tol_flat
    xi, zi, Yi          % grid arrays
    tris                % Ntri x 9
    Ntri
    geom_source_note
end

methods
    % ── Constructor ──────────────────────────────────────────────────
    function obj = HullGeometry(varargin)
        p = inputParser;
        addParameter(p,'Lpp',      obj.Lpp);
        addParameter(p,'CB_target',obj.CB_target);
        addParameter(p,'LB',       obj.LB);
        addParameter(p,'BT',       obj.BT);
        addParameter(p,'Nst',      obj.Nst);
        addParameter(p,'Nwl',      obj.Nwl);
        addParameter(p,'geometry_source', obj.geometry_source);
        parse(p, varargin{:});
        f = fieldnames(p.Results);
        for k = 1:numel(f); obj.(f{k}) = p.Results.(f{k}); end

        obj.B        = obj.Lpp / obj.LB;
        obj.T        = obj.B  / obj.BT;
        obj.tol_flat = 1e-3 * (obj.B/2);

        obj = obj.buildOffsets();
        obj = obj.buildTriangles();
    end

    % ── Signed volume of closed STL mesh ─────────────────────────────
    function sv = signedVolume(obj)
        sv = 0;
        for t = 1:obj.Ntri
            sv = sv + dot(obj.tris(t,1:3), ...
                          cross(obj.tris(t,4:6), obj.tris(t,7:9)));
        end
        sv = sv / 6;
    end
end  % methods

% ── Private methods ──────────────────────────────────────────────────
methods (Access = private)

    function obj = buildOffsets(obj)
        src = obj.geometry_source;
        if strcmpi(src,'legacy_table3')
            obj = obj.buildLegacyTable3();
        elseif strcmpi(src,'html_reference')
            obj = obj.buildHtmlReference();
        else
            error('Unknown geometry_source "%s"', src);
        end
    end

    % ── Legacy Table 3 reconstruction ────────────────────────────────
    function obj = buildLegacyTable3(obj)
        obj.geom_source_note = ...
            'Legacy Table 3 reconstruction (Todd 1963 DTMB-1712)';

        xS_fp_nd = [ 0.000;0.025;0.050;0.075;0.100;0.150;0.200;0.250;0.300;
                     0.350;0.400;0.450;0.500;0.550;0.600;0.650;0.700;0.750;
                     0.800;0.850;0.900;0.925;0.950;0.975;1.000 ];
        xS = flipud(1 - xS_fp_nd) * obj.Lpp;

        zW_nd            = [0.000;0.075;0.250;0.500;0.750;1.000];
        max_hb_nd        = [0.710 0.866 0.985 1.000 1.000 1.000];

        t3 = [ ...
          0.000 0.000 0.000 0.000 0.000 0.000 0.000
          0.009 0.032 0.042 0.041 0.043 0.051 0.042
          0.013 0.064 0.082 0.087 0.090 0.102 0.085
          0.019 0.095 0.126 0.141 0.148 0.160 0.135
          0.024 0.127 0.178 0.204 0.213 0.228 0.192
          0.055 0.196 0.294 0.346 0.368 0.391 0.323
          0.134 0.314 0.436 0.502 0.535 0.562 0.475
          0.275 0.466 0.589 0.660 0.691 0.718 0.630
          0.469 0.630 0.733 0.802 0.824 0.841 0.771
          0.666 0.779 0.854 0.906 0.917 0.926 0.880
          0.810 0.898 0.935 0.971 0.977 0.979 0.955
          0.945 0.964 0.979 0.996 1.000 1.000 0.990
          1.000 1.000 1.000 1.000 1.000 1.000 1.000
          0.965 0.982 0.990 1.000 1.000 1.000 0.996
          0.882 0.922 0.958 0.994 1.000 1.000 0.977
          0.767 0.826 0.892 0.962 0.987 0.994 0.938
          0.622 0.701 0.781 0.884 0.943 0.975 0.863
          0.463 0.560 0.639 0.754 0.857 0.937 0.750
          0.309 0.413 0.483 0.592 0.728 0.857 0.609
          0.168 0.267 0.330 0.413 0.541 0.725 0.445
          0.065 0.152 0.193 0.236 0.321 0.536 0.268
          0.032 0.102 0.130 0.156 0.216 0.425 0.187
          0.014 0.058 0.076 0.085 0.116 0.308 0.109
          0.010 0.020 0.020 0.022 0.033 0.193 0.040
          0.000 0.000 0.000 0.000 0.000 0.082 0.004];

        CM_ref = 0.977;
        hb_nd  = flipud(t3(:,1:6) .* max_hb_nd);
        obj.xi = linspace(0, obj.Lpp, obj.Nst)';
        obj.zi = linspace(0, obj.T,   obj.Nwl)';
        zi_nd  = obj.zi / obj.T;

        sp = zeros(numel(xS), obj.Nwl);
        for k = 1:numel(xS)
            sp(k,:) = max(interp1(zW_nd, hb_nd(k,:)', zi_nd,'pchip'), 0) * (obj.B/2);
        end
        obj.Yi = zeros(obj.Nst, obj.Nwl);
        for j = 1:obj.Nwl
            obj.Yi(:,j) = max(interp1(xS, sp(:,j), obj.xi,'pchip'), 0);
        end
        obj.Yi = min(obj.Yi, obj.B/2);
    end

    % ── HTML reference (requires external .js file) ───────────────────
    function obj = buildHtmlReference(obj)
        project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
        js_path = fullfile(project_root, 'web', 'data', ...
                           'series60_cb060_geometry_data.js');
        if ~isfile(js_path)
            warning('JS file not found – falling back to legacy_table3.');
            obj.geometry_source = 'legacy_table3';
            obj = obj.buildLegacyTable3();
            return
        end
        raw = fileread(js_path);
        tok = regexp(raw, ...
            'const\s+hullMesh\s*=\s*\{\s*x:\s*\[(?<x>[\s\S]*?)\],\s*y:\s*\[(?<y>[\s\S]*?)\],\s*z:\s*\[(?<z>[\s\S]*?)\],\s*i:', ...
            'names','once');
        if isempty(tok); error('Cannot parse hullMesh from JS file.'); end
        parseArr = @(s) sscanf(regexprep(s,'[,\r\n]+',' '),'%f');
        xr = parseArr(tok.x);  yr = parseArr(tok.y);  zr = parseArr(tok.z);
        xU = unique(xr,'stable');  zU = unique(zr,'stable');
        nx = numel(xU); nz = numel(zU);
        yM = reshape(yr,[nz,nx]).';
        Lref= max(xU); Tref=max(zU); Bref=Lref/7.5;
        x_ref = flipud(Lref - xU(:)) / Lref * obj.Lpp;
        z_ref = zU(:) / Tref * obj.T;
        y_ref = flipud(yM) / (Bref/2) * (obj.B/2);
        obj.xi = linspace(0,obj.Lpp,obj.Nst)';
        obj.zi = linspace(0,obj.T,  obj.Nwl)';
        yx = zeros(obj.Nst,nz);
        for j=1:nz
            yx(:,j) = max(interp1(x_ref, y_ref(:,j), obj.xi,'pchip'),0);
        end
        obj.Yi = zeros(obj.Nst,obj.Nwl);
        for k=1:obj.Nst
            obj.Yi(k,:) = max(interp1(z_ref, yx(k,:)', obj.zi,'pchip'),0);
        end
        obj.Yi(end,:) = 0;
        obj.geom_source_note = sprintf('HTML reference (%d x %d)',nx,nz);
    end

    % ── Triangle mesh builder ─────────────────────────────────────────
    function obj = buildTriangles(obj)
        xi=obj.xi; zi=obj.zi; Y=obj.Yi;
        Ns=obj.Nst; Nw=obj.Nwl;
        tris = zeros(4*(Ns-1)*(Nw-1) + 4*(Ns-1) + 4*(Nw-1), 9);
        row  = 0;

        addTri = @(A,B,C) [A B C];

        % Starboard + port hull surface
        for k=1:Ns-1
          for j=1:Nw-1
            P00=[xi(k),  Y(k,j),   zi(j)];   P10=[xi(k+1),Y(k+1,j),  zi(j)];
            P01=[xi(k),  Y(k,j+1), zi(j+1)]; P11=[xi(k+1),Y(k+1,j+1),zi(j+1)];
            Q00=[xi(k), -Y(k,j),   zi(j)];   Q10=[xi(k+1),-Y(k+1,j),  zi(j)];
            Q01=[xi(k), -Y(k,j+1), zi(j+1)]; Q11=[xi(k+1),-Y(k+1,j+1),zi(j+1)];
            row=row+1; tris(row,:)=addTri(P00,P10,P11);
            row=row+1; tris(row,:)=addTri(P00,P11,P01);
            row=row+1; tris(row,:)=addTri(Q00,Q11,Q10);
            row=row+1; tris(row,:)=addTri(Q00,Q01,Q11);
          end
        end
        % Keel
        for k=1:Ns-1
            A=[xi(k), -Y(k,1),   0]; B_=[xi(k+1),-Y(k+1,1),0];
            C=[xi(k+1), Y(k+1,1),0]; D=[xi(k),    Y(k,1),   0];
            row=row+1; tris(row,:)=addTri(A,B_,C);
            row=row+1; tris(row,:)=addTri(A,C,D);
        end
        % Waterplane
        for k=1:Ns-1
            A=[xi(k),   Y(k,end),  obj.T]; B_=[xi(k+1), Y(k+1,end),  obj.T];
            C=[xi(k+1),-Y(k+1,end),obj.T]; D=[xi(k),   -Y(k,end),    obj.T];
            row=row+1; tris(row,:)=addTri(A,B_,C);
            row=row+1; tris(row,:)=addTri(A,C,D);
        end
        % AP transom
        for j=1:Nw-1
            A=[0, Y(1,j),  zi(j)];  B_=[0, Y(1,j+1),  zi(j+1)];
            C=[0,-Y(1,j+1),zi(j+1)]; D=[0,-Y(1,j),    zi(j)];
            row=row+1; tris(row,:)=addTri(A,B_,C);
            row=row+1; tris(row,:)=addTri(A,C,D);
        end
        % FP transom
        for j=1:Nw-1
            A=[obj.Lpp, Y(end,j),  zi(j)];  B_=[obj.Lpp,-Y(end,j),   zi(j)];
            C=[obj.Lpp,-Y(end,j+1),zi(j+1)]; D=[obj.Lpp, Y(end,j+1), zi(j+1)];
            row=row+1; tris(row,:)=addTri(A,B_,C);
            row=row+1; tris(row,:)=addTri(A,C,D);
        end
        tris = tris(1:row,:);
        % Orient outward
        sv = 0;
        for t=1:row
            sv = sv + dot(tris(t,1:3), cross(tris(t,4:6),tris(t,7:9)));
        end
        if sv/6 < 0
            tris = tris(:,[1:3 7:9 4:6]);
        end
        obj.tris = tris;
        obj.Ntri = row;
    end

end  % private methods
end  % classdef
