param(
    # Folder where the Excel file and the images folder live
    [string]$BaseFolder       = "C:\Users\salgado.jp\Downloads\Danilo Suntal",

    # Excel file name with the org info
    [string]$ExcelFileName    = "organization.xlsx",

    # Subfolder under BaseFolder that contains the .png photos
    [string]$ImagesFolderName = "images",

    # Sheet name in the Excel file that holds the org data
    [string]$SheetName        = "Org Chart",

    # Output PowerPoint file name
    [string]$OutputPptName    = "OrgChart.pptx"
)

# ---------- PATH SETUP AND BASIC CHECKS ----------

$excelPath     = Join-Path $BaseFolder $ExcelFileName
$imagesPath    = Join-Path $BaseFolder $ImagesFolderName
$outputPptPath = Join-Path $BaseFolder $OutputPptName

Write-Host "Excel file:  $excelPath"
Write-Host "Images dir:  $imagesPath"
Write-Host "Output pptx: $outputPptPath"
Write-Host ""

if (!(Test-Path $excelPath)) {
    throw "Excel file not found at $excelPath"
}
if (!(Test-Path $imagesPath)) {
    throw "Images folder not found at $imagesPath"
}

# ---------- STEP 1: READ EXCEL INTO MEMORY ----------

Write-Host "Reading Excel..."

# Start Excel via COM (invisible)
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false

$workbook  = $excel.Workbooks.Open($excelPath)
$worksheet = $workbook.Worksheets.Item($SheetName)
$used      = $worksheet.UsedRange

# Map header names → column indices
$headerMap = @{}
for ($col = 1; $col -le $used.Columns.Count; $col++) {
    $header = $worksheet.Cells.Item(1, $col).Text
    if ($header) { $headerMap[$header] = $col }
}

# We expect these columns in the sheet
foreach ($h in "Unique Identifier","Name","Reports To","Line Detail 1") {
    if (-not $headerMap.ContainsKey($h)) {
        throw "Column '$h' not found in sheet '$SheetName'."
    }
}

$colId    = $headerMap["Unique Identifier"]
$colName  = $headerMap["Name"]
$colBoss  = $headerMap["Reports To"]
$colTitle = $headerMap["Line Detail 1"]

# Read each row into a PSCustomObject
$people = @()
for ($row = 2; $row -le $used.Rows.Count; $row++) {
    $id = $worksheet.Cells.Item($row, $colId).Value2
    if (-not $id) { continue }   # skip empty rows

    $name      = $worksheet.Cells.Item($row, $colName).Value2
    $reportsTo = $worksheet.Cells.Item($row, $colBoss).Value2
    $title     = $worksheet.Cells.Item($row, $colTitle).Value2

    # Build expected picture path based on Unique Identifier + ".png"
    $picPath = Join-Path $imagesPath ($id + ".png")
    if (-not (Test-Path $picPath)) {
        # If not found, we keep $picPath = $null, but don't break the script
        $picPath = $null
    }

    $people += [PSCustomObject]@{
        ID        = $id
        Name      = $name
        ReportsTo = $reportsTo
        Title     = $title
        Picture   = $picPath
    }
}

# Close Excel cleanly
$workbook.Close($false)
$excel.Quit()

[System.Runtime.InteropServices.Marshal]::ReleaseComObject($worksheet) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook)  | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)     | Out-Null
[GC]::Collect()
[GC]::WaitForPendingFinalizers()

Write-Host "Loaded $($people.Count) people from Excel."
Write-Host ""

# ---------- STEP 2: BUILD HIERARCHY AND FIND ROOT ----------

# Build dictionaries:
#   peopleById[ID] -> person
#   children[ManagerID] -> list of child IDs
$peopleById = @{}
$children   = @{}

foreach ($p in $people) {
    $peopleById[$p.ID] = $p
    if ($p.ReportsTo) {
        if (-not $children.ContainsKey($p.ReportsTo)) {
            $children[$p.ReportsTo] = @()
        }
        $children[$p.ReportsTo] += $p.ID
    }
}

# Root = the person with no "Reports To" (Danilo)
$roots = @($people | Where-Object { -not $_.ReportsTo })
if ($roots.Count -lt 1) { throw "No root found (no blank 'Reports To' in Excel)." }
if ($roots.Count -gt 1) { Write-Warning "Multiple roots; using the first one." }
$root = $roots[0]

Write-Host "Root: $($root.Name) [$($root.ID)]"
Write-Host ""

# Direct reports of root (Danilo) = level 2
$level2Ids = @()
if ($children.ContainsKey($root.ID)) {
    $level2Ids = $children[$root.ID]
} else {
    throw "Root '$($root.Name)' has no direct reports."
}

# ---------- HELPER FUNCTIONS ----------

# Returns all descendants (all depths) of a manager ID
function Get-Descendants {
    param([string]$managerId)

    $result = New-Object System.Collections.Generic.List[string]
    $stack  = New-Object System.Collections.Stack
    $stack.Push($managerId)

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        if ($children.ContainsKey($current)) {
            foreach ($childId in $children[$current]) {
                $result.Add($childId)
                $stack.Push($childId)
            }
        }
    }
    return $result
}

# Turns full names into shorter, display-friendly names:
#   - Title Case
#   - "First Middle Last" → "First M. Last"
#   - "First Middle Last1 Last2" → "First M. Last1" (drops final surname)
#   - Removes "(On Leave)" text for display
function Format-DisplayName {
    param([string]$fullName)

    if (-not $fullName) { return "" }

    # Remove anything after "(" (e.g. "(On Leave)")
    $base = $fullName.Split("(")[0].Trim()
    if (-not $base) { $base = $fullName.Trim() }

    # Split into tokens
    $tokens = $base -split "\s+"
    $tokens = $tokens | Where-Object { $_ -ne "" }

    if ($tokens.Count -eq 0) { return "" }

    # Helper: Title Case a word
    $textInfo = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo
    function LocalTitle($w) {
        return $textInfo.ToTitleCase($w.ToLowerInvariant())
    }

    if ($tokens.Count -eq 1) {
        return LocalTitle $tokens[0]
    }

    if ($tokens.Count -eq 2) {
        $first = LocalTitle $tokens[0]
        $last  = LocalTitle $tokens[1]
        return "$first $last"
    }

    # Exactly 3 tokens: First Middle Last -> First M. Last
    if ($tokens.Count -eq 3) {
        $first  = LocalTitle $tokens[0]
        $middle = LocalTitle $tokens[1]
        $last   = LocalTitle $tokens[2]
        $mi     = $middle[0]          # first letter of middle
        return "$first $mi. $last"
    }

    # 4 or more tokens: First Middle Last1 Last2 ... -> First M. Last1
    # (Drops final surname(s) to keep it short)
    $first  = LocalTitle $tokens[0]
    $middle = LocalTitle $tokens[1]
    $last   = LocalTitle $tokens[$tokens.Count - 2]  # second-to-last token
    $mi     = $middle[0]

    return "$first $mi. $last"
}

# Writes text into a shape:
#   - Uses Format-DisplayName
#   - Applies base font size
#   - Slightly shrinks font for very long names
function Set-NameText {
    param(
        [object]$shape,
        [string]$fullName,
        [int]$baseFontSize,
        [int]$minFontSize = 6
    )

    $name = Format-DisplayName $fullName
    $shape.TextFrame.TextRange.Text = $name

    $len = $name.Length
    $fontSize = $baseFontSize

    # Simple heuristic to shrink font for long names
    if     ($len -gt 24) { $fontSize = [Math]::Max($minFontSize, $baseFontSize - 2) }
    elseif ($len -gt 18) { $fontSize = [Math]::Max($minFontSize, $baseFontSize - 1) }

    $shape.TextFrame.TextRange.Font.Size = $fontSize
    $shape.TextFrame.TextRange.ParagraphFormat.Alignment = 2  # center
    $shape.TextFrame.VerticalAnchor = 3                       # middle
}

# ---------- STEP 3: OPEN POWERPOINT ----------

Write-Host "Starting PowerPoint..."

$pp = New-Object -ComObject PowerPoint.Application
$pp.Visible = [Microsoft.Office.Core.MsoTriState]::msoTrue

$pres  = $pp.Presentations.Add()
$slide = $pres.Slides.Add(1, 12) # 12 = ppLayoutBlank (blank slide)

$slideWidth  = $pres.PageSetup.SlideWidth
$slideHeight = $pres.PageSetup.SlideHeight

# ---------- LAYOUT SETTINGS ----------

# Asymmetric margins to nudge everything a bit left:
#   left  = 17, right = 33
$leftMargin       = 17
$rightMargin      = 33

$topMargin        = 20
$verticalGapRootToMgr = 30   # gap from Danilo to manager row
$verticalGapMgrToEmp  = 20   # gap from manager row to first team member
$empVerticalGap       = 6    # vertical gap between employees in a column

$picSize         = 16         # picture edge size (square)
$picGap          = 4          # gap between picture and text box

$rootBoxWidth    = 100
$rootBoxHeight   = 36

$mgrBoxWidthBase = 70         # base box width for managers (may be scaled)
$mgrBoxHeight    = 30

$empBoxWidthBase = 60         # base box width for employees (may be scaled)
$empBoxHeight    = 24

$rootNameFont    = 9
$mgrNameFont     = 8
$empNameFont     = 7

# ---------- STEP 4: DRAW ROOT (DANILO) ----------

$shapeById = @{}  # stores the "main" shape per person (for connectors if needed)

# Center Danilo horizontally on the slide
$rootX = ($slideWidth - $rootBoxWidth) / 2
$rootY = $topMargin

# Draw Danilo's rectangle
$rootRect = $slide.Shapes.AddShape(1, $rootX, $rootY, $rootBoxWidth, $rootBoxHeight)
Set-NameText -shape $rootRect -fullName $root.Name -baseFontSize $rootNameFont
$rootRect.Line.Visible = -1   # no border

# Danilo's picture to the left of the box (not grouped, so easier layout)
if ($root.Picture) {
    $picX = $rootX - $picSize - $picGap
    $picY = $rootY + ($rootBoxHeight - $picSize) / 2
    $slide.Shapes.AddPicture($root.Picture, $false, $true,
                             $picX, $picY, $picSize, $picSize) | Out-Null
}

$shapeById[$root.ID] = $rootRect

# ---------- STEP 5: DRAW LEVEL 2 (DIRECT REPORTS) ----------

$managerCount   = $level2Ids.Count
$availableWidth = $slideWidth - $leftMargin - $rightMargin - 10

# Column width = picture + gap + box + padding
$colWidth   = $mgrBoxWidthBase + $picSize + $picGap + 8
$totalWidth = $colWidth * $managerCount

# If managers don't fit, scale their box widths down
if ($totalWidth -gt $availableWidth - 1) {
    $scale = ($availableWidth - 1) / $totalWidth
    $mgrBoxWidthBase = [Math]::Max(45, [Math]::Floor($mgrBoxWidthBase * $scale))
    $empBoxWidthBase = [Math]::Max(40, [Math]::Floor($empBoxWidthBase * $scale))
    $colWidth   = $mgrBoxWidthBase + $picSize + $picGap + 8
    $totalWidth = $colWidth * $managerCount
}

$mgrBoxWidth = $mgrBoxWidthBase
$empBoxWidth = $empBoxWidthBase

# Y position of manager row
$mgrRowY = $rootRect.Top + $rootRect.Height + $verticalGapRootToMgr

# We'll store each manager rectangle and its column center
$managerRectById  = @{}
$colCenterByMgrId = @{}

for ($i = 0; $i -lt $managerCount; $i++) {
    $mgrId = $level2Ids[$i]
    $mgr   = $peopleById[$mgrId]

    # Column center X for this manager (using left/right margins)
    $colCenterX = $leftMargin + ($i + 0.5) * $colWidth
    $mgrX       = $colCenterX - $mgrBoxWidth / 2

    # Manager's name box
    $mgrRect = $slide.Shapes.AddShape(1, $mgrX, $mgrRowY, $mgrBoxWidth, $mgrBoxHeight)
    Set-NameText -shape $mgrRect -fullName $mgr.Name -baseFontSize $mgrNameFont
    $mgrRect.Line.Visible = -1

    # Manager's picture left of the box
    if ($mgr.Picture) {
        $picX = $mgrX - $picSize - $picGap
        $picY = $mgrRowY + ($mgrBoxHeight - $picSize) / 2
        $slide.Shapes.AddPicture($mgr.Picture, $false, $true,
                                 $picX, $picY, $picSize, $picSize) | Out-Null
    }

    $shapeById[$mgrId]       = $mgrRect
    $managerRectById[$mgrId] = $mgrRect
    $colCenterByMgrId[$mgrId]= $colCenterX
}

# ---------- STEP 6: BUS-STYLE CONNECTORS FROM ROOT TO LEVEL 2 ----------

# Instead of 11 direct lines, we do:
#   short line from Danilo down -> horizontal bus -> short lines down to each manager

if ($managerCount -gt 0) {
    $rootCenterX = $rootRect.Left + $rootRect.Width / 2
    $rootBottomY = $rootRect.Top + $rootRect.Height

    # Y position of the horizontal bus (slightly below Danilo, above managers)
    $busY = $rootBottomY + 10

    # Short vertical line from Danilo to the bus line
    $rootToBus = $slide.Shapes.AddConnector(1, $rootCenterX, $rootBottomY, $rootCenterX, $busY)
    $rootToBus.Line.ForeColor.RGB = 0x000000

    # Compute min and max X among manager column centers
    $mgrCenters = $colCenterByMgrId.Values
    $minX = ($mgrCenters | Measure-Object -Minimum).Minimum
    $maxX = ($mgrCenters | Measure-Object -Maximum).Maximum

    # Horizontal bus line from the first to the last manager center
    $busLine = $slide.Shapes.AddLine($minX, $busY, $maxX, $busY)
    $busLine.Line.ForeColor.RGB = 0x000000

    # For each manager: short vertical line from bus to manager box
    foreach ($mgrId in $level2Ids) {
        $mgrRect = $managerRectById[$mgrId]
        $mgrCenterX = $mgrRect.Left + $mgrRect.Width / 2
        $mgrTopY    = $mgrRect.Top

        $busToMgr = $slide.Shapes.AddConnector(1, $mgrCenterX, $busY, $mgrCenterX, $mgrTopY)
        $busToMgr.Line.ForeColor.RGB = 0x000000
    }
}

# ---------- STEP 7: DRAW LEVEL 3 TEAM MEMBERS (NO CONNECTORS) ----------

# All people deeper in the tree are drawn in columns under each manager, 
# but we do NOT draw connectors for them, per your requirement.

$teamTopStart = $mgrRowY + $mgrBoxHeight + $verticalGapMgrToEmp

foreach ($mgrId in $level2Ids) {
    $mgrRect = $managerRectById[$mgrId]

    # All descendants under this manager at any depth
    $teamIds = Get-Descendants -managerId $mgrId
    if ($teamIds.Count -eq 0) { continue }

    $colCenterX = $colCenterByMgrId[$mgrId]
    $empX       = $colCenterX - $empBoxWidth / 2

    $index = 0
    foreach ($empId in $teamIds) {
        $emp = $peopleById[$empId]
        if (-not $emp) { continue }

        # Vertical position, stacked downwards
        $empY = $teamTopStart + $index * ($empBoxHeight + $empVerticalGap)

        # Safety: stop drawing if we go beyond slide height
        if ($empY + $empBoxHeight -gt $slideHeight - 10) { break }

        # Employee name box
        $empRect = $slide.Shapes.AddShape(1, $empX, $empY, $empBoxWidth, $empBoxHeight)
        Set-NameText -shape $empRect -fullName $emp.Name -baseFontSize $empNameFont
        $empRect.Line.Visible = -1

        # Employee picture left of the box
        if ($emp.Picture) {
            $picX = $empX - $picSize - $picGap
            $picY = $empY + ($empBoxHeight - $picSize) / 2
            $slide.Shapes.AddPicture($emp.Picture, $false, $true,
                                     $picX, $picY, $picSize, $picSize) | Out-Null
        }

        $shapeById[$empId] = $empRect

        # No connectors from level 2 → level 3
        $index++
    }
}

# ---------- STEP 8: SAVE POWERPOINT ----------

Write-Host "Saving to $outputPptPath ..."
$pres.SaveAs($outputPptPath)
Write-Host "Done. Open the PPTX and review the layout."