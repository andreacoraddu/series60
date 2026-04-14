# MATLAB Hull Generation

This folder contains the MATLAB workflow used to reconstruct the Series 60 CB = 0.60 hull, compute hydrostatics, visualize the geometry, and export boundary-element-method input files.

## Structure

- `Series60_Hull_BEM.m`
  Main runner script. It sets up paths, builds the hull, runs hydrostatic checks, opens the figures, and writes export files.
- `src/HullGeometry.m`
  Geometry class that builds the offset table, interpolated station and waterline grids, and the closed triangle mesh.
- `src/HullHydrostatics.m`
  Hydrostatics class that computes displacement, coefficients, waterplane area, centers, and stability-related quantities from the generated hull.
- `src/HullVisualiser.m`
  Visualization class that renders body plan, 3D hull, sectional area, half-breadth map, waterlines, mesh diagnostics, and the sanity dashboard.
- `outputs/`
  Generated artifacts such as STL, Nemoh, WAMIT, and hydrostatics report files.
- `legacy/`
  Older scratch material kept only for reference.

## Typical Workflow

Open MATLAB in the repository root or in this `matlab/` folder, then run:

```matlab
run('matlab/Series60_Hull_BEM.m')
```

Or, if you are already inside `matlab/`:

```matlab
run('Series60_Hull_BEM.m')
```

The script automatically adds `src/` to the MATLAB path and writes exports into `outputs/`.

## Geometry Sources

`HullGeometry` supports two geometry inputs:

- `legacy_table3`
  Reconstructs the hull from the historical offset data embedded in the class.
- `html_reference`
  Rebuilds the hull from the web geometry data stored in `../web/data/series60_cb060_geometry_data.js`.

The current runner uses `legacy_table3` by default.

## Generated Outputs

Running the script writes:

- `outputs/Series60_BEM.stl`
  Closed ASCII STL mesh of the hull.
- `outputs/Series60_Nemoh.dat`
  Half-hull panel mesh for Nemoh-style solvers.
- `outputs/Series60_WAMIT.gdf`
  Half-hull panel definition for WAMIT.
- `outputs/Series60_hydrostatics.txt`
  Text summary of the main hydrostatic properties and sanity-check results.

## Notes

- The classes are written in an object-oriented style so geometry generation, hydrostatics, and plotting stay separated.
- The export script is designed around a 1 m reference hull unless you change the `Lpp` parameter in the runner.
- `legacy/untitled.m` is not part of the active workflow.
