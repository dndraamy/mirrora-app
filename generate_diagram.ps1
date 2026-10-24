Add-Type -AssemblyName System.Drawing

$width = 1400
$height = 950
$bmp = New-Object System.Drawing.Bitmap $width, $height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::White)

$penBlack = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)
$penThick = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2.5)
$penBox = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)
$brushBlack = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
$brushFill = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255))

$fontTitle = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)
$fontActor = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
$fontText = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Regular)
$fontTextBold = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)

# System Boundary Box
$boxX = 360
$boxY = 60
$boxW = 960
$boxH = 830
$g.DrawRectangle($penBox, $boxX, $boxY, $boxW, $boxH)
$g.DrawString("«mobile app»", (New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Italic)), $brushBlack, ($boxX + 20), ($boxY + 15))
$g.DrawString("Mirrora App", $fontTitle, $brushBlack, ($boxX + 20), ($boxY + 35))

# Stickman Actor (User)
$actorCenterX = 150
$actorCenterY = 460

# Head
$headR = 28
$g.DrawEllipse($penThick, ($actorCenterX - $headR), ($actorCenterY - 140), ($headR * 2), ($headR * 2))

# Body
$g.DrawLine($penThick, $actorCenterX, ($actorCenterY - 84), $actorCenterX, ($actorCenterY + 10))

# Arms
$g.DrawLine($penThick, ($actorCenterX - 45), ($actorCenterY - 45), $actorCenterX, ($actorCenterY - 60))
$g.DrawLine($penThick, $actorCenterX, ($actorCenterY - 60), ($actorCenterX + 45), ($actorCenterY - 45))

# Legs
$g.DrawLine($penThick, $actorCenterX, ($actorCenterY + 10), ($actorCenterX - 35), ($actorCenterY + 90))
$g.DrawLine($penThick, $actorCenterX, ($actorCenterY + 10), ($actorCenterX + 35), ($actorCenterY + 90))

# Actor Label
$sfCenter = New-Object System.Drawing.StringFormat
$sfCenter.Alignment = [System.Drawing.StringAlignment]::Center
$sfCenter.LineAlignment = [System.Drawing.StringAlignment]::Center
$g.DrawString("User`n(Pengguna)", $fontActor, $brushBlack, $actorCenterX, ($actorCenterY + 125), $sfCenter)

# Use Cases
$useCases = @(
    @{ Title = "Auth (Login, Register & Biometrik)"; Sub = "" },
    @{ Title = "Konsultasi AI Skincare"; Sub = "(Teks & Unggah Foto Kulit)" },
    @{ Title = "Mengelola Rutinitas Harian"; Sub = "(Checklist Skincare & Notifikasi)" },
    @{ Title = "Melihat & Memfilter"; Sub = "Katalog Produk Kosmetik" },
    @{ Title = "Konversi Nilai Tukar"; Sub = "Multi-Mata Uang (Kurs)" },
    @{ Title = "Mencari Toko Kosmetik Terdekat"; Sub = "(LBS / GPS & OpenStreetMap)" },
    @{ Title = "Memainkan Minigame Sensor"; Sub = "(Shake to Pick & Bubble Pop)" },
    @{ Title = "Mengikuti Giveaway &"; Sub = "Memverifikasi Blockchain Proof" }
)

$ovalW = 340
$ovalH = 76
$ovalX1 = 440
$ovalX2 = 880

# Two columns of ovals or stacked ovals?
# In image 1 it's stacked and slightly staggered or single column.
# With 8 use cases, let's stack them nicely:
$startY = 120
$gapY = 92

# Setup arrow cap
$cap = New-Object System.Drawing.Drawing2D.AdjustableArrowCap(5, 5, $true)
$penArrow = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 1.8)
$penArrow.CustomEndCap = $cap

for ($i = 0; $i -lt $useCases.Count; $i++) {
    $y = $startY + ($i * $gapY)
    
    # Slight stagger like in the user's photo
    $curOvalX = if ($i % 2 -eq 0) { 560 } else { 720 }
    if ($useCases.Count -gt 6) {
        # Clean staggered 2-column or 1-column layout
        $curOvalX = if ($i -lt 4) { 480 } else { 820 }
        $curY = if ($i -lt 4) { 150 + ($i * 150) } else { 150 + (($i - 4) * 150) }
    } else {
        $curY = $y
    }
    
    $rect = New-Object System.Drawing.Rectangle $curOvalX, $curY, $ovalW, $ovalH
    $g.FillEllipse($brushFill, $rect)
    $g.DrawEllipse($penThick, $rect)
    
    # Text
    $uc = $useCases[$i]
    $text = if ($uc.Sub -ne "") { "$($uc.Title)`n$($uc.Sub)" } else { $uc.Title }
    $g.DrawString($text, $fontText, $brushBlack, ($curOvalX + ($ovalW / 2)), ($curY + ($ovalH / 2)), $sfCenter)
    
    # Arrow from Actor to Oval
    $startX = $actorCenterX + 45
    $startYPos = $actorCenterY - 45
    $targetX = $curOvalX
    $targetY = $curY + ($ovalH / 2)
    $g.DrawLine($penArrow, $startX, $startYPos, $targetX, $targetY)
}

$outputPath = "c:\src\vscode_flutter\mirrora\mirrora-app\use_case_diagram_mirrora.png"
$bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
Write-Host "Diagram generated at $outputPath"
