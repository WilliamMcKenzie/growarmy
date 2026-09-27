local Layout = {Columns = 8, Gap = 6, MaxCellSize = 54}
function Layout.metrics(count, availableWidth, availableHeight)
 local cell = math.max(1, math.min(Layout.MaxCellSize, math.floor((availableWidth - (Layout.Columns - 1) * Layout.Gap) / Layout.Columns)))
 local rows = math.ceil(count / Layout.Columns)
 local height = math.max(0, rows * (cell + Layout.Gap) - Layout.Gap)
 return {
  cell = cell, rows = rows, width = Layout.Columns * (cell + Layout.Gap) - Layout.Gap,
  contentHeight = height, viewHeight = math.min(height, math.max(cell, availableHeight)),
 }
end
function Layout.position(index, metrics)
 local column = (index - 1) % Layout.Columns
 local row = math.floor((index - 1) / Layout.Columns)
 return column * (metrics.cell + Layout.Gap), (metrics.rows - row - 1) * (metrics.cell + Layout.Gap)
end
function Layout.canMerge(source, target, maxTier)
 return source ~= target and source.class == target.class and source.tier == target.tier and source.tier < maxTier
end
return Layout
