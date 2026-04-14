classdef HullVisualiser
% HullVisualiser  All hull sanity-check and mesh visualisation plots.
%%  v = HullVisualiser(geom, hydro)
%  v.plotAll()          % render every figure
%%  Individual plots:
%    plotBodyPlan()
%    plot3DHull()
%    plotSAC()
%    plotHalfbreadthMap()
%    plotHydroPanel()
%    plotWaterlines()
%    plotMeshQuality()
%    plotNormalDeviation()
%    plotSanityDashboard(checks)

properties (Access = private)
    g     % HullGeometry
    h     % HullHydrostatics
    cdwl  = [0.85 0.15 0.15];
    cbase = [0.10 0.10 0.10];
    ccl   = [0.55 0.55 0.55];
end

methods
    function obj = HullVisualiser(geom, hydro)
        obj.g = geom;
        obj.h = hydro;
    end

    function plotAll(obj, checks)
        if nargin < 2; checks = []; end
        obj.plotBodyPlan();
        obj.plot3DHull();
        obj.plotSAC();
        obj.plotHalfbreadthMap();
        obj.plotHydroPanel();
        obj.plotWaterlines();
        obj.plotMeshQuality();
        obj.plotNormalDeviation();
        if ~isempty(checks)
            obj.plotSanityDashboard(checks);
        end
    end

    % ── 1. Body Plan ──────────────────────────────────────────────────
    function plotBodyPlan(obj)
        g = obj.g;
        Nshow = 30;
        idx  = unique(round(linspace(1, g.Nst, Nshow)));
        Nc   = numel(idx);
        cmap = interp1([0;0.4;0.6;1], ...
            [0.08 0.45 0.80; 0.40 0.70 0.92; 0.92 0.38 0.28; 0.72 0.08 0.08], ...
            linspace(0,1,Nc));

        f  = figure('Name','1 - Body Plan','Color','w','Position',[60 60 700 560]);
        ax = axes(f,'Color',[0.96 0.97 0.97],'GridColor',[1 1 1],'GridAlpha',1);
        hold(ax,'on'); box(ax,'on'); grid(ax,'on');

        for ii = 1:Nc
            k  = idx(ii);
            ys = g.Yi(k,:)';
            yb = ys(1);
            if yb > g.tol_flat
                yc = [yb; ys; ys(end); -flipud(ys); -yb; yb];
                zc = [0;  g.zi; g.zi(end); flipud(g.zi); 0; 0];
            else
                yc = [0; ys; ys(end); -flipud(ys); 0];
                zc = [0; g.zi; g.zi(end); flipud(g.zi); 0];
            end
            plot(ax, yc, zc, 'Color', cmap(ii,:), 'LineWidth', 1.0);
        end

        plot(ax, [-g.B/2*1.12  g.B/2*1.12], [g.T  g.T], '--', 'Color', obj.cdwl,  'LineWidth', 2.0);
        plot(ax, [-g.B/2*1.12  g.B/2*1.12], [0    0  ], '-',  'Color', obj.cbase, 'LineWidth', 1.8);
        plot(ax, [0 0], [-g.T*0.06  g.T*1.12], ':', 'Color', obj.ccl, 'LineWidth', 0.9);

        text(ax,  g.B/2*0.42,  g.T*1.05, 'DWL',      'Color', obj.cdwl,  'FontSize', 11, 'FontWeight', 'bold', 'Interpreter', 'none');
        text(ax,  0.0015,     -g.T*0.08,  'Baseline', 'Color', obj.cbase, 'FontSize', 9,  'Interpreter', 'none');
        text(ax,  0.0015,      g.T*0.50,  'CL',       'Color', obj.ccl,   'FontSize', 9,  'Rotation', 90, 'Interpreter', 'none');

        xlabel(ax, 'y  [m]',              'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');
        ylabel(ax, 'z  [m]  keel to DWL', 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');
        title(ax,  sprintf('Body Plan  -  Series 60  CB=%.2f  Lpp=%.3f m', g.CB_target, g.Lpp), ...
              'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');

        xlim(ax, [-g.B/2*1.18  g.B/2*1.18]);
        ylim(ax, [-g.T*0.18    g.T*1.22   ]);
        axis(ax, 'equal');
        set(ax, 'DataAspectRatio', [1 1 1], 'FontSize', 11, 'TickDir', 'out');

        colormap(ax, cmap); 
        caxis(ax, [0 1]); % Fixed for backwards compatibility

        cb = colorbar(ax, 'eastoutside', 'Ticks', [0 0.5 1], 'TickLabels', {'AP','Mid','FP'});
        cb.Label.String      = 'Station';
        cb.Label.FontSize    = 10;
        cb.Label.Interpreter = 'none';
    end

    % ── 2. 3D Hull – Aligned Styling & True Aspect Ratio ──────────────
    function plot3DHull(obj)
        g  = obj.g;
        Xs = repmat(g.xi,  1, g.Nwl);
        Zs = repmat(g.zi', g.Nst, 1);

        % Curvature-based colour field (fixed gradient dimensions)
        dx_s = g.xi(2) - g.xi(1);
        dz_s = g.zi(2) - g.zi(1);
        [dYdz, dYdx] = gradient(g.Yi, dz_s, dx_s); 
        curv   = sqrt(dYdx.^2 + dYdz.^2);
        curv_n = curv / (max(curv(:)) + eps);

        % Figure & axes (Styled to match the rest of the plots)
        f  = figure('Name','2 - 3D Hull','Color','w','Position',[80 60 1340 780]);
        ax = axes(f,'Color','w','Position',[0.03 0.07 0.80 0.86]);
        hold(ax,'on'); grid(ax,'on'); box(ax,'on');

        % Standard colormap compatible with white backgrounds
        colormap(ax, parula(256));
        caxis(ax, [0.00 0.55]);

        % Main hull surfaces (port + starboard)
        surf(ax, Xs,  g.Yi, Zs, curv_n, ...
             'EdgeColor','none','FaceAlpha',0.90,'FaceLighting','gouraud');
        surf(ax, Xs, -g.Yi, Zs, curv_n, ...
             'EdgeColor','none','FaceAlpha',0.90,'FaceLighting','gouraud');

        % Transom end-cap (AP)
        Ny_ap  = 40;
        Nwl_n  = numel(g.zi);
        zGrd_ap = repmat(g.zi(:)', Ny_ap, 1);
        xGrd_ap = zeros(Ny_ap, Nwl_n);
        yGrd_ap = zeros(Ny_ap, Nwl_n);
        for jj = 1:Nwl_n
            yGrd_ap(:,jj) = linspace(-g.Yi(1,jj), g.Yi(1,jj), Ny_ap)';
        end
        surf(ax, xGrd_ap, yGrd_ap, zGrd_ap, zeros(Ny_ap, Nwl_n), ...
             'EdgeColor','none','FaceAlpha',0.50,'FaceLighting','gouraud');

        % Waterplane cap (DWL)
        Ny_wp = 4;
        xWP   = repmat(g.xi(:)', Ny_wp, 1);
        yWP   = zeros(Ny_wp, g.Nst);
        frac  = linspace(-1, 1, Ny_wp)';
        for ii = 1:Ny_wp
            yWP(ii,:) = frac(ii) * g.Yi(:,end)';
        end
        surf(ax, xWP, yWP, g.T*ones(Ny_wp, g.Nst), 0.12*ones(Ny_wp, g.Nst), ...
             'EdgeColor','none','FaceAlpha',0.28,'FaceLighting','flat');

        % Outlines and primary lines
        dwlCol = obj.cdwl;
        plot3(ax, g.xi,  g.Yi(:,end), g.T*ones(g.Nst,1), '-','Color',dwlCol,'LineWidth',2.0);
        plot3(ax, g.xi, -g.Yi(:,end), g.T*ones(g.Nst,1), '-','Color',dwlCol,'LineWidth',2.0);
        plot3(ax, g.xi, zeros(g.Nst,1), zeros(g.Nst,1), '-','Color',obj.cbase,'LineWidth',2.0);
        
        stemCol = [0.40 0.40 0.40];
        plot3(ax, g.Lpp*ones(g.Nwl,1),  g.Yi(end,:)', g.zi, '-','Color',stemCol,'LineWidth',1.4);
        plot3(ax, g.Lpp*ones(g.Nwl,1), -g.Yi(end,:)', g.zi, '-','Color',stemCol,'LineWidth',1.4);
        plot3(ax, zeros(g.Nwl,1),  g.Yi(1,:)', g.zi, '-','Color',stemCol,'LineWidth',1.4);
        plot3(ax, zeros(g.Nwl,1), -g.Yi(1,:)', g.zi, '-','Color',stemCol,'LineWidth',1.4);

        % Selected waterlines
        Nwl_show = 9;
        wlIdx = unique(round(linspace(1, g.Nwl-1, Nwl_show)));
        for ii = 1:numel(wlIdx)
            j   = wlIdx(ii);
            plot3(ax, g.xi,  g.Yi(:,j), g.zi(j)*ones(g.Nst,1), '-','Color',[0.1 0.4 0.7 0.3],'LineWidth',0.9);
            plot3(ax, g.xi, -g.Yi(:,j), g.zi(j)*ones(g.Nst,1), '-','Color',[0.1 0.4 0.7 0.3],'LineWidth',0.9);
        end

        % Selected transverse sections
        sIdx = unique(round(linspace(1, g.Nst, 20)));
        for k = sIdx
            plot3(ax, g.xi(k)*ones(g.Nwl,1),  g.Yi(k,:)', g.zi, '-','Color',[0.1 0.4 0.7 0.3],'LineWidth',0.6);
            plot3(ax, g.xi(k)*ones(g.Nwl,1), -g.Yi(k,:)', g.zi, '-','Color',[0.1 0.4 0.7 0.3],'LineWidth',0.6);
        end

        % Centreline symmetry plane ghost
        vx = [0, g.Lpp, g.Lpp, 0]; vy = [0, 0, 0, 0]; vz = [0, 0, g.T, g.T];
        fill3(vx, vy, vz, obj.ccl, 'FaceAlpha', 0.15, 'EdgeColor', obj.ccl, 'EdgeAlpha', 0.4, 'Parent', ax);

        % Standard ambient lighting
        delete(findobj(f,'Type','light'));
        light('Parent',ax,'Position',[ 0.5*g.Lpp,  5.0*g.B,  8.0*g.T],'Style','infinite','Color',[1 1 1]);
        light('Parent',ax,'Position',[-0.5*g.Lpp, -4.0*g.B,  3.0*g.T],'Style','local',   'Color',[0.7 0.7 0.7]);
        lighting(ax,'gouraud');
        material(ax,'dull');

        % Colorbar
        cb = colorbar(ax,'eastoutside');
        cb.Color = 'k';
        cb.Label.String = 'Shape gradient |dy/ds| (curvature proxy)';
        cb.Label.FontSize = 10;
        cb.Label.Interpreter = 'none';

        % Axis labels & title
        xlabel(ax,'x  [m]   AP to FP','Color','k','FontSize',12,'FontWeight','bold','Interpreter','none');
        ylabel(ax,'y  [m]',          'Color','k','FontSize',12,'FontWeight','bold','Interpreter','none');
        zlabel(ax,'z  [m]',          'Color','k','FontSize',12,'FontWeight','bold','Interpreter','none');
        title(ax, sprintf('3D Hull - Series 60   CB=%.2f   Lpp=%.3f m', g.CB_target, g.Lpp), ...
              'Color','k','FontSize',13,'FontWeight','bold','Interpreter','none');

        % Axes appearance
        set(ax,'XColor','k','YColor','k','ZColor','k', ...
               'GridColor',[0.6 0.6 0.6],'GridAlpha',0.4, ...
               'FontSize',10,'TickDir','out','Projection','perspective','LineWidth',0.8);
        grid(ax,'minor');

        % TRUE ASPECT RATIO
        axis(ax, 'equal');
        
        xlim(ax, [-0.04*g.Lpp,  1.04*g.Lpp]);
        ylim(ax, [-g.B/2*1.45,  g.B/2*1.45]);
        zlim(ax, [-g.T*0.2,     g.T*1.50   ]);
        view(ax, -44, 20);
    end

    % ── 3. Sectional Area Curve ───────────────────────────────────────
    function plotSAC(obj)
        g = obj.g; h = obj.h;
        f  = figure('Name','3 - Sectional Area Curve','Color','w','Position',[60 640 580 420]);
        ax = axes(f);
        hold(ax,'on'); grid(ax,'on'); box(ax,'on');

        fill(ax, [0; h.Asec/(g.B*g.T); 0], ...
                 [g.xi(1)/g.Lpp; g.xi/g.Lpp; g.xi(end)/g.Lpp], ...
                 [0.74 0.87 0.96],'EdgeColor','none','FaceAlpha',0.55, ...
                 'DisplayName','Computed (interpolated)');

        plot(ax, h.Asec/(g.B*g.T), g.xi/g.Lpp, '-', ...
             'Color',[0.08 0.38 0.72],'LineWidth',2.4, ...
             'DisplayName','Computed (interpolated)');

        if strcmpi(g.geometry_source,'legacy_table3')
            aref_fp  = [0.000;0.042;0.085;0.135;0.192;0.323;0.475;0.630;0.771; ...
                        0.880;0.955;0.990;1.000;0.996;0.977;0.938;0.863;0.750; ...
                        0.609;0.445;0.268;0.187;0.109;0.040;0.004];
            xS_fp_nd = [0.000;0.025;0.050;0.075;0.100;0.150;0.200;0.250;0.300; ...
                        0.350;0.400;0.450;0.500;0.550;0.600;0.650;0.700;0.750; ...
                        0.800;0.850;0.900;0.925;0.950;0.975;1.000];
            xS_ap   = flipud(1 - xS_fp_nd);
            aref_ap = flipud(aref_fp) * 0.977;

            plot(ax, aref_ap, xS_ap, '--r','LineWidth',1.6, ...
                 'DisplayName','Todd Table 3 reference');

            a_ref_i = interp1(xS_ap, aref_ap, g.xi/g.Lpp,'pchip','extrap');
            err     = h.Asec/(g.B*g.T) - a_ref_i(:);

            yyaxis(ax,'right');
            plot(ax, err, g.xi/g.Lpp,'-','Color',[0.80 0.40 0.10],'LineWidth',1.2, ...
                 'DisplayName','Error vs Todd');
            yline(ax,0,':','Color',[0.5 0.5 0.5],'LineWidth',0.8,'HandleVisibility','off');
            ylabel(ax,'Error  (computed - reference)','FontSize',10,'FontWeight','bold','Interpreter','none');
            ax.YAxis(2).Color = [0.80 0.40 0.10];
            yyaxis(ax,'left');

            legend(ax,{'Computed (interpolated)','','Todd Table 3 reference','Error vs Todd'}, ...
                   'Location','northeast','FontSize',9,'Interpreter','none');
        end

        xlabel(ax,'Asec / (B x T)',      'FontSize',12,'FontWeight','bold','Interpreter','none');
        ylabel(ax,'x / Lpp  (AP=0)',     'FontSize',12,'FontWeight','bold','Interpreter','none');
        title(ax, 'Sectional Area Curve','FontSize',13,'FontWeight','bold','Interpreter','none');
        set(ax,'YDir','normal','FontSize',11,'TickDir','out');
        xlim(ax,[0 1.05]); ylim(ax,[0 1]);
    end

    % ── 4. Half-breadth contour map ───────────────────────────────────
    function plotHalfbreadthMap(obj)
        g = obj.g;
        f  = figure('Name','4 - Half-breadth Map','Color','w','Position',[660 640 580 420]);
        ax = axes(f);
        contourf(ax, g.zi/g.T, g.xi/g.Lpp, g.Yi/(g.B/2), 30,'LineColor','none');
        hold(ax,'on');
        xS_fp_nd = [0:0.025:0.1, 0.15:0.05:0.9, 0.925:0.025:1.0]'; %#ok<NBRAK>
        for xp = flipud(1-xS_fp_nd)'
            plot(ax,[0 1],[xp xp],'-','Color',[1 1 1 0.30],'LineWidth',0.4);
        end
        colormap(ax,parula(256)); cb = colorbar(ax);
        cb.Label.String      = 'y / (B/2)';
        cb.Label.FontSize    = 10;
        cb.Label.Interpreter = 'none';
        xlabel(ax,'z / T',          'FontSize',12,'FontWeight','bold','Interpreter','none');
        ylabel(ax,'x / Lpp (AP=0)','FontSize',12,'FontWeight','bold','Interpreter','none');
        title(ax, 'Half-breadth Distribution','FontSize',13,'FontWeight','bold','Interpreter','none');
        set(ax,'FontSize',11,'YDir','normal','TickDir','out');
    end

    % ── 5. Hydrostatics text panel ────────────────────────────────────
    function plotHydroPanel(obj)
        g = obj.g; h = obj.h;
        f  = figure('Name','5 - Hydrostatics','Color','w','Position',[1260 640 360 420]);
        ax = axes(f); axis(ax,'off');

        ht = {'\bfHydrostatics\rm'; ' ';
              sprintf('CB   = %.4f', h.CB);
              sprintf('CM   = %.4f', h.CM);
              sprintf('CWP  = %.4f', h.CWP);
              sprintf('CP   = %.4f', h.CP); ' ';
              sprintf('KB   = %.4f m', h.KB);
              sprintf('BM   = %.4f m', h.BM);
              sprintf('KM   = %.4f m', h.KM); ' ';
              sprintf('Awp  = %.5f m2', h.Awp);
              sprintf('Vol  = %.6f m3', h.Vol);
              sprintf('Disp = %.4f t',  h.Disp_t); ' ';
              sprintf('LCB  = %.2f%% Lpp', h.LCBpct)};

        text(ax,0.05,0.97,ht,'Units','normalized','VerticalAlignment','top', ...
             'FontSize',11,'Interpreter','tex','FontName','Courier New');
        title(ax,sprintf('Series 60  Lpp=%.3f m',g.Lpp), ...
              'FontSize',11,'FontWeight','bold','Interpreter','none');
    end

    % ── 6. Waterline plan view ────────────────────────────────────────
    function plotWaterlines(obj)
        g     = obj.g;
        wlIdx = unique(round(linspace(1, g.Nwl, 10)));
        cmap  = cool(numel(wlIdx));

        f  = figure('Name','6 - Waterline Plan','Color','w','Position',[60 1080 860 320]);
        ax = axes(f); hold(ax,'on'); grid(ax,'on'); box(ax,'on');

        for ii = 1:numel(wlIdx)
            j   = wlIdx(ii);
            lbl = sprintf('z/T=%.2f', g.zi(j)/g.T);
            plot(ax,g.xi, g.Yi(:,j),'-','Color',cmap(ii,:),'LineWidth',1.2,'DisplayName',lbl);
            plot(ax,g.xi,-g.Yi(:,j),'-','Color',cmap(ii,:),'LineWidth',1.2,'HandleVisibility','off');
        end
        plot(ax,[0 0],[-g.B/2 g.B/2]*1.1,':','Color',obj.ccl,'LineWidth',0.8,'HandleVisibility','off');

        xlabel(ax,'x  [m]   (AP to FP)','FontSize',11,'FontWeight','bold','Interpreter','none');
        ylabel(ax,'y  [m]',             'FontSize',11,'FontWeight','bold','Interpreter','none');
        title(ax, 'Waterline Plan View', 'FontSize',12,'FontWeight','bold','Interpreter','none');
        legend(ax,'Location','eastoutside','FontSize',8,'Interpreter','none');
        set(ax,'FontSize',10,'TickDir','out'); axis(ax,'equal');
    end

    % ── 7. Mesh quality ───────────────────────────────────────────────
    function plotMeshQuality(obj)
        g  = obj.g; Ns = g.Nst; Nw = g.Nwl;
        panelArea   = zeros(Ns-1, Nw-1);
        aspectRatio = zeros(Ns-1, Nw-1);

        for k = 1:Ns-1
          for j = 1:Nw-1
            dx_l  = g.xi(k+1)-g.xi(k);
            dz_l  = g.zi(j+1)-g.zi(j);
            ds_x  = sqrt(dx_l^2 + (g.Yi(k+1,j)-g.Yi(k,j))^2);
            panelArea(k,j)   = ds_x*dz_l*1e6;
            aspectRatio(k,j) = max(ds_x,dz_l)/(min(ds_x,dz_l)+eps);
          end
        end

        xc = 0.5*(g.xi(1:end-1)+g.xi(2:end));
        zc = 0.5*(g.zi(1:end-1)+g.zi(2:end));

        f   = figure('Name','7 - Mesh Quality','Color','w','Position',[60 1080 960 420]);
        
        sp1 = subplot(1,2,1,'Parent',f);
        contourf(sp1,zc/g.T,xc/g.Lpp,panelArea,20,'LineColor','none');
        colormap(sp1,hot(256)); cb1=colorbar(sp1);
        cb1.Label.String='Panel area  [mm^2]'; cb1.Label.FontSize=10; cb1.Label.Interpreter='none';
        xlabel(sp1,'z / T','FontSize',11,'FontWeight','bold','Interpreter','none');
        ylabel(sp1,'x / Lpp','FontSize',11,'FontWeight','bold','Interpreter','none');
        title(sp1, 'Panel Area','FontSize',11,'FontWeight','bold','Interpreter','none');
        set(sp1,'YDir','normal','FontSize',10,'TickDir','out');

        sp2 = subplot(1,2,2,'Parent',f);
        contourf(sp2,zc/g.T,xc/g.Lpp,aspectRatio,20,'LineColor','none');
        colormap(sp2,turbo(256)); cb2=colorbar(sp2);
        cb2.Label.String='Aspect ratio'; cb2.Label.FontSize=10; cb2.Label.Interpreter='none';
        xlabel(sp2,'z / T','FontSize',11,'FontWeight','bold','Interpreter','none');
        ylabel(sp2,'x / Lpp','FontSize',11,'FontWeight','bold','Interpreter','none');
        title(sp2, 'Panel Aspect Ratio','FontSize',11,'FontWeight','bold','Interpreter','none');
        set(sp2,'YDir','normal','FontSize',10,'TickDir','out');

        sgtitle(f,'Mesh Quality','FontSize',13,'FontWeight','bold','Interpreter','none');
    end

    % ── 8. Normal-vector deviation ────────────────────────────────────
    function plotNormalDeviation(obj)
        g  = obj.g; Ns = g.Nst; Nw = g.Nwl;
        normDev = zeros(Ns, Nw);

        for k = 2:Ns-1
          for j = 2:Nw-1
            dydx_l = (g.Yi(k+1,j)-g.Yi(k-1,j))/(g.xi(k+1)-g.xi(k-1));
            dydz_l = (g.Yi(k,j+1)-g.Yi(k,j-1))/(g.zi(j+1)-g.zi(j-1));
            nv     = [-dydx_l, 1, -dydz_l];
            nv     = nv/norm(nv);
            normDev(k,j) = acosd(abs(nv(2)));
          end
        end
        
        % Fixed boundary conditions
        normDev(1, :)  = normDev(2, :);
        normDev(end,:) = normDev(end-1, :);
        normDev(:, 1)  = normDev(:, 2);
        normDev(:, end)= normDev(:, end-1);

        f  = figure('Name','8 - Normal Deviation','Color','w','Position',[60 1080 820 380]);
        ax = axes(f);
        contourf(ax,g.zi/g.T,g.xi/g.Lpp,normDev,25,'LineColor','none');
        colormap(ax,jet(256)); cb=colorbar(ax);
        cb.Label.String='Angle from hull-normal  [deg]'; cb.Label.FontSize=10; cb.Label.Interpreter='none';
        xlabel(ax,'z / T','FontSize',12,'FontWeight','bold','Interpreter','none');
        ylabel(ax,'x / Lpp','FontSize',12,'FontWeight','bold','Interpreter','none');
        title(ax, 'Surface Normal Deviation (smoothness)','FontSize',13,'FontWeight','bold','Interpreter','none');
        set(ax,'YDir','normal','FontSize',11,'TickDir','out');
    end

    % ── 9. Sanity-check dashboard ─────────────────────────────────────
    function plotSanityDashboard(obj, checks) %#ok<INUSL>
        n  = numel(checks);
        f  = figure('Name','9 - Sanity Dashboard','Color','w','Position',[900 80 780 70+n*34]);
        ax = axes(f); hold(ax,'on'); axis(ax,'off');
        ylim(ax,[0 n+1]); xlim(ax,[0 1]);

        for i = 1:n
            ci  = n+1-i;
            clr = [0.15 0.65 0.25]; lbl = 'PASS';
            if ~checks(i).passed; clr=[0.85 0.15 0.15]; lbl='FAIL'; end
            rectangle(ax,'Position',[0.005 ci-0.38 0.10 0.76], ...
                'FaceColor',clr,'EdgeColor','none','Curvature',0.3);
            text(ax,0.055,ci,lbl,'HorizontalAlignment','center', ...
                'Color','w','FontSize',8,'FontWeight','bold','Interpreter','none');
            text(ax,0.125,ci,sprintf('#%02d  %s',i,checks(i).label), ...
                'FontSize',9.5,'VerticalAlignment','middle','Interpreter','none');
        end
        title(ax,'Hull Sanity Check Results','FontSize',12,'FontWeight','bold','Interpreter','none');
    end

end % methods
end % classdef