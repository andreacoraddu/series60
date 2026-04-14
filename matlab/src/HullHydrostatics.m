classdef HullHydrostatics
% HullHydrostatics  Computes all hydrostatic coefficients from HullGeometry.
%
%  hs = HullHydrostatics(geom)
%  hs = HullHydrostatics(geom, 'rho', 1025, 'g', 9.81)

properties (SetAccess = private)
    CB, CM, CWP, CP
    KB, BM, KM
    LCB, LCBpct
    Awp, Vol, Disp_t
    Asec          % sectional area curve [Nst x 1]
    rho = 1025
    g   = 9.81
end

methods
    function obj = HullHydrostatics(geom, varargin)
        p = inputParser;
        addParameter(p,'rho', obj.rho);
        addParameter(p,'g',   obj.g);
        parse(p, varargin{:});
        obj.rho = p.Results.rho;
        obj.g   = p.Results.g;
        obj = obj.compute(geom);
    end

    function print(obj)
        fprintf('--- Hydrostatics ---\n');
        fprintf(' CB=%.4f  CM=%.4f  CWP=%.4f  CP=%.4f\n', obj.CB,obj.CM,obj.CWP,obj.CP);
        fprintf(' KB=%.4fm  BM=%.4fm  KM=%.4fm\n',         obj.KB,obj.BM,obj.KM);
        fprintf(' Awp=%.5fm²  Vol=%.6fm³  Disp=%.4ft\n',   obj.Awp,obj.Vol,obj.Disp_t);
        fprintf(' LCB=%.4fm (%.2f%% Lpp)\n\n',             obj.LCB, obj.LCBpct);
    end
end

methods (Access = private)
    function obj = compute(obj, g)
        xi=g.xi; zi=g.zi; Y=g.Yi;
        Lpp=g.Lpp; B=g.B; T=g.T;

        % Waterplane
        obj.Awp = 2*trapz(xi, Y(:,end));
        obj.CWP = obj.Awp / (Lpp*B);

        % Sectional areas
        Ns = numel(xi);
        obj.Asec = zeros(Ns,1);
        for k=1:Ns
            obj.Asec(k) = 2*trapz(zi, Y(k,:)');
        end
        obj.Vol  = trapz(xi, obj.Asec);
        obj.CB   = obj.Vol / (Lpp*B*T);

        % Midship coefficient (station closest to midship)
        imid = round(Ns/2);
        obj.CM = 2*trapz(zi, Y(imid,:)') / (B*T);
        obj.CP = obj.CB / obj.CM;

        % LCB
        obj.LCB    = trapz(xi, obj.Asec .* xi) / obj.Vol;
        obj.LCBpct = obj.LCB / Lpp * 100;

        % KB via volume-weighted centroid
        KB_num=0; dV_sum=0;
        for k=1:Ns-1
          for j=1:numel(zi)-1
            dA  = 0.25*(Y(k,j)+Y(k+1,j)+Y(k,j+1)+Y(k+1,j+1))*2;
            dV  = dA*(xi(k+1)-xi(k))*(zi(j+1)-zi(j));
            KB_num = KB_num + dV*0.5*(zi(j)+zi(j+1));
            dV_sum = dV_sum + dV;
          end
        end
        obj.KB = KB_num / dV_sum;

        % BM
        Ix     = (2/3)*trapz(xi, Y(:,end).^3);
        obj.BM = Ix / obj.Vol;
        obj.KM = obj.KB + obj.BM;

        obj.Disp_t = obj.Vol * obj.rho / 1e3;
    end
end
end