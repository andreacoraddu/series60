%% Series60_Hull_BEM v7  -  OOP refactor of Series 60 CB=0.60 BEM exporter
%  Run:  Series60_Hull_BEM()
clc; clear; close all;

script_dir = fileparts(mfilename('fullpath'));
matlab_root = resolveMatlabRoot(script_dir);
src_dir = fullfile(matlab_root, 'src');
output_dir = fullfile(matlab_root, 'outputs');

if ~isPathEntry(path, src_dir)
    addpath(src_dir);
end

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

fprintf('\n==============================================\n');
fprintf('  Series 60 – BEM Hull Generator (OOP)\n');
fprintf('==============================================\n');

%% ── 1. BUILD GEOMETRY ──────────────────────────────────────────────
geom = HullGeometry( ...
    'Lpp',            1.0, ...
    'Nst',            120, ...
    'Nwl',            60,  ...
    'geometry_source','legacy_table3');

fprintf(' Lpp=%.4f m  B=%.4f m  T=%.4f m  CB_target=%.2f\n\n', ...
    geom.Lpp, geom.B, geom.T, geom.CB_target);

%% ── 2. HYDROSTATICS ────────────────────────────────────────────────
hydro = HullHydrostatics(geom, 'rho', 1025, 'g', 9.81);
hydro.print();

%% ── 3. SANITY CHECKS ───────────────────────────────────────────────
checks = runSanityChecks(geom, hydro);

num_passed = sum([checks.passed]);
num_total  = numel(checks);

fprintf('=== RESULT: %d/%d checks passed', num_passed, num_total);
if num_passed == num_total
    fprintf(' – Hull VALID for BEM\n\n');
else
    fprintf(' – Review FAILs above!\n\n');
end

%% ── 4. PLOTS ───────────────────────────────────────────────────────
vis = HullVisualiser(geom, hydro);
vis.plotAll(checks);

%% ── 5. EXPORTS ─────────────────────────────────────────────────────
exportSTL(geom, output_dir);
exportNemoh(geom, output_dir);
exportWAMIT(geom, output_dir);
exportHydroText(geom, hydro, num_passed, num_total, output_dir);

fprintf('\n==============================================\n');
fprintf('  Done. Hull ready for BEM solver.\n');
fprintf('==============================================\n');


%% ══════════════════════════════════════════════════════════════════════
%% LOCAL FUNCTIONS
%% ══════════════════════════════════════════════════════════════════════

function matlab_root = resolveMatlabRoot(script_dir)
    candidates = {
        script_dir
        fileparts(script_dir)
    };

    for idx = 1:numel(candidates)
        candidate = candidates{idx};
        if isfile(fullfile(candidate, 'src', 'HullGeometry.m'))
            matlab_root = candidate;
            return
        end
    end

    error(['Unable to locate MATLAB source folder. Expected to find ' ...
           'src/HullGeometry.m near %s.'], script_dir);
end

function tf = isPathEntry(path_string, target_dir)
    entries = strsplit(path_string, pathsep);
    tf = any(strcmp(entries, target_dir));
end

% ── Sanity Checks ─────────────────────────────────────────────────────
function checks = runSanityChecks(g, h)
    % Initialize an empty struct array
    checks = struct('label', {}, 'passed', {});

    % Nested helper function for clean, dynamic appending
    function add(lbl, ok)
        checks(end+1) = struct('label', lbl, 'passed', logical(ok));
    end

    % End closures
    add(sprintf('FP closure max=%.2e m', max(abs(g.Yi(end,:)))), max(abs(g.Yi(end,:))) < 1e-3);
    add(sprintf('AP half-breadth max=%.5f m', max(g.Yi(1,:))),   max(g.Yi(1,:)) <= g.B/2 + 1e-6);

    % Half-breadth bounds
    eY = abs(max(g.Yi(:)) - g.B/2) / (g.B/2) * 100;
    add(sprintf('Max half-breadth err=%.2f%% (tol 1.5%%)', eY), eY < 1.5);
    add(sprintf('No negative offsets min=%.2e m', min(g.Yi(:))), min(g.Yi(:)) >= -1e-6);

    % Hydrostatic Coefficients
    add(sprintf('CWP=%.4f [0.60–0.85]', h.CWP), h.CWP > 0.60 && h.CWP < 0.85);
    add(sprintf('CB=%.4f err=%.4f (tol 0.02)', h.CB, abs(h.CB-g.CB_target)), abs(h.CB-g.CB_target) < 0.02);
    add(sprintf('CM=%.4f [0.94–1.00]', h.CM), h.CM > 0.94 && h.CM < 1.0);
    add(sprintf('LCB=%.2f%% [48–53%%]', h.LCBpct), h.LCBpct > 48 && h.LCBpct < 53);
    add(sprintf('CP=%.4f [0.58–0.70]', h.CP), h.CP > 0.58 && h.CP < 0.70);
    add(sprintf('KB=%.4f [0.2T–0.6T]', h.KB), h.KB > 0.2*g.T && h.KB < 0.6*g.T);

    % BEM panel count check
    n_pan = 2 * (g.Nst-1) * (g.Nwl-1);
    add(sprintf('BEM panels=%d (min 400)', n_pan), n_pan >= 400);

    % Volumes
    sv = g.signedVolume();
    ev = abs(sv - h.Vol) / h.Vol * 100;
    add(sprintf('STL signed vol=%.6f m³ (>0)', sv), sv > 0);
    add(sprintf('STL vs trapz vol err=%.4f%% (tol 0.5%%)', ev), ev < 0.5);

    % Print results to console
    for i = 1:numel(checks)
        if checks(i).passed
            fprintf(' [PASS] #%02d %s\n', i, checks(i).label);
        else
            fprintf(' [FAIL] #%02d %s\n', i, checks(i).label);
        end
    end
end

% ── STL Exporter ──────────────────────────────────────────────────────
function exportSTL(g, output_dir)
    sname = fullfile(output_dir, 'Series60_BEM.stl');
    fid   = fopen(sname, 'w');
    if fid < 0; error('Cannot open %s for writing.', sname); end

    fprintf(fid, 'solid Series60_CB060_Lpp%.4fm\n', g.Lpp);
    for t = 1:g.Ntri
        P1 = g.tris(t, 1:3);
        P2 = g.tris(t, 4:6);
        P3 = g.tris(t, 7:9);

        nv = cross(P2-P1, P3-P1);
        nn = norm(nv);
        if nn < 1e-14; continue; end
        nv = nv / nn;

        fprintf(fid, ' facet normal %.8e %.8e %.8e\n', nv(1), nv(2), nv(3));
        fprintf(fid, '  outer loop\n');
        fprintf(fid, '   vertex %.8e %.8e %.8e\n', P1(1), P1(2), P1(3));
        fprintf(fid, '   vertex %.8e %.8e %.8e\n', P2(1), P2(2), P2(3));
        fprintf(fid, '   vertex %.8e %.8e %.8e\n', P3(1), P3(2), P3(3));
        fprintf(fid, '  endloop\n');
        fprintf(fid, ' endfacet\n');
    end
    fprintf(fid, 'endsolid Series60_CB060_Lpp%.4fm\n', g.Lpp);
    fclose(fid);

    d = dir(sname);
    fprintf('=== Exports ======================================\n');
    fprintf(' %s (%.1f KB, %d triangles)\n', sname, d.bytes/1024, g.Ntri);
end

% ── Nemoh Exporter ────────────────────────────────────────────────────
function exportNemoh(g, output_dir)
    nf = fullfile(output_dir, 'Series60_Nemoh.dat');

    % Generate linear node list
    nodes = zeros(g.Nst * g.Nwl, 3);
    for k = 1:g.Nst
        for j = 1:g.Nwl
            nodes((k-1)*g.Nwl+j, :) = [g.xi(k), g.Yi(k,j), g.zi(j)-g.T];
        end
    end

    Nn = size(nodes, 1);
    Nq = (g.Nst-1) * (g.Nwl-1);

    fid = fopen(nf, 'w');
    if fid < 0; error('Cannot open %s for writing.', nf); end

    fprintf(fid, '# Nemoh Series60 CB=0.60 Lpp=%.4fm z=0@DWL\n', g.Lpp);
    fprintf(fid, '%d 0\n', Nn);

    % Write nodes
    for n = 1:Nn
        fprintf(fid, '%d %.6f %.6f %.6f\n', n, nodes(n,1), nodes(n,2), nodes(n,3));
    end

    fprintf(fid, '%d\n', Nq);

    % Write quads (Anti-clockwise winding -> Normal points INTO the body)
    for k = 1:g.Nst-1
        for j = 1:g.Nwl-1
            p1 = (k-1)*g.Nwl + j;
            p2 = k*g.Nwl + j;
            p3 = k*g.Nwl + j + 1;
            p4 = (k-1)*g.Nwl + j + 1;
            fprintf(fid, '%d %d %d %d\n', p1, p2, p3, p4);
        end
    end
    fclose(fid);

    d = dir(nf);
    fprintf(' %s (%.1f KB, %d quads)\n', nf, d.bytes/1024, Nq);
end

% ── WAMIT Exporter ────────────────────────────────────────────────────
function exportWAMIT(g, output_dir)
    gf  = fullfile(output_dir, 'Series60_WAMIT.gdf');
    fid = fopen(gf, 'w');
    if fid < 0; error('Cannot open %s for writing.', gf); end

    fprintf(fid, 'Series60 CB=0.60 Lpp=%.4fm z=0@DWL ISX=1\n', g.Lpp);
    fprintf(fid, '%.4f %.3f\n', g.Lpp, 9.81);
    fprintf(fid, '0 1\n'); % ILOWHI=0, ISYMM=1 (y=0 is a symmetry plane)

    Nq = (g.Nst-1) * (g.Nwl-1);
    fprintf(fid, '%d\n', Nq);

    % Write quads (Anti-clockwise winding -> Normal points INTO the body)
    for k = 1:g.Nst-1
        for j = 1:g.Nwl-1
            fprintf(fid, '%.6f %.6f %.6f\n', g.xi(k),   g.Yi(k,j),     g.zi(j)  -g.T);
            fprintf(fid, '%.6f %.6f %.6f\n', g.xi(k+1), g.Yi(k+1,j),   g.zi(j)  -g.T);
            fprintf(fid, '%.6f %.6f %.6f\n', g.xi(k+1), g.Yi(k+1,j+1), g.zi(j+1)-g.T);
            fprintf(fid, '%.6f %.6f %.6f\n', g.xi(k),   g.Yi(k,j+1),   g.zi(j+1)-g.T);
        end
    end
    fclose(fid);

    d = dir(gf);
    fprintf(' %s (%.1f KB, %d quads, ISX=1)\n', gf, d.bytes/1024, Nq);
end

% ── Text Report ───────────────────────────────────────────────────────
function exportHydroText(g, h, num_passed, num_total, output_dir)
    rf  = fullfile(output_dir, 'Series60_hydrostatics.txt');
    fid = fopen(rf, 'w');
    if fid < 0; error('Cannot open %s for writing.', rf); end

    % Replaced deprecated datestr(now)
    fprintf(fid, 'Series60 CB=0.60 Hydrostatics %s\n', char(datetime('now')));
    fprintf(fid, 'Lpp=%.4fm B=%.4fm T=%.4fm\n', g.Lpp, g.B, g.T);
    fprintf(fid, 'CB=%.4f CM=%.4f CWP=%.4f CP=%.4f\n', h.CB, h.CM, h.CWP, h.CP);
    fprintf(fid, 'KB=%.4fm BM=%.4fm KM=%.4fm\n', h.KB, h.BM, h.KM);
    fprintf(fid, 'Awp=%.5fm2 Vol=%.6fm3 Disp=%.4ft\n', h.Awp, h.Vol, h.Disp_t);
    fprintf(fid, 'LCB=%.4fm (%.2f%% Lpp)\n', h.LCB, h.LCBpct);
    fprintf(fid, 'Sanity: %d/%d passed\n', num_passed, num_total);

    fclose(fid);
    fprintf(' %s\n', rf);
end
