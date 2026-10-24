Add-Type -AssemblyName System.Drawing

$outputPath = "c:\src\vscode_flutter\mirrora\mirrora-app\diagrams\class_diagram_mirrora.png"
$w = 1280
$h = 920

$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::White)

$penBlack2 = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)
$penBlack15 = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 1.5)
$penBlack1 = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 1.2)
$brushBlack = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
$brushWhite = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)

$fontTitle = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
$fontMember = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Regular)
$fontCard = New-Object System.Drawing.Font("Arial", 9.5, [System.Drawing.FontStyle]::Bold)
$fontCaption = New-Object System.Drawing.Font("Times New Roman", 13, [System.Drawing.FontStyle]::Regular)

$sfCenter = New-Object System.Drawing.StringFormat
$sfCenter.Alignment = [System.Drawing.StringAlignment]::Center
$sfCenter.LineAlignment = [System.Drawing.StringAlignment]::Center

$sfLeft = New-Object System.Drawing.StringFormat
$sfLeft.Alignment = [System.Drawing.StringAlignment]::Near
$sfLeft.LineAlignment = [System.Drawing.StringAlignment]::Center

# Function to draw UML 3-compartment Class Box
function Draw-UmlClass ($x, $y, $w, $name, [array]$attrs, [array]$methods) {
    $headerH = 28
    $attrH = [Math]::Max(24, ($attrs.Count * 17) + 8)
    $methodH = if ($methods.Count -gt 0) { [Math]::Max(24, ($methods.Count * 17) + 8) } else { 20 }
    $totalH = $headerH + $attrH + $methodH

    # Background
    $g.FillRectangle($brushWhite, $x, $y, $w, $totalH)
    $g.DrawRectangle($penBlack15, $x, $y, $w, $totalH)

    # Header line
    $g.DrawLine($penBlack15, $x, ($y + $headerH), ($x + $w), ($y + $headerH))
    $g.DrawString($name, $fontTitle, $brushBlack, ($x + ($w / 2)), ($y + ($headerH / 2)), $sfCenter)

    # Attributes
    $curY = $y + $headerH + 10
    foreach ($a in $attrs) {
        $g.DrawString($a, $fontMember, $brushBlack, ($x + 8), $curY, $sfLeft)
        $curY += 17
    }

    # Method separator line
    $methodLineY = $y + $headerH + $attrH
    $g.DrawLine($penBlack15, $x, $methodLineY, ($x + $w), $methodLineY)

    # Methods
    $curY = $methodLineY + 10
    foreach ($m in $methods) {
        $g.DrawString($m, $fontMember, $brushBlack, ($x + 8), $curY, $sfLeft)
        $curY += 17
    }

    return @{ X=$x; Y=$y; W=$w; H=$totalH; CenterX=($x + ($w/2)); CenterY=($y + ($totalH/2)) }
}

# 1. User Class (Center-Left)
$cUser = Draw-UmlClass 70 280 230 "User" @(
    "+Id: string",
    "+Name: string",
    "+Email: string",
    "+IsBiometric: bool",
    "+CreatedAt: DateTime"
) @(
    "+Login(): bool",
    "+Register(): bool",
    "+UpdateProfile(): void",
    "+ToggleBiometric(): void",
    "+ShakeDevice(): void"
)

# 2. DailyRoutine Class (Center)
$cRoutine = Draw-UmlClass 400 290 230 "DailyRoutine" @(
    "+Id: string",
    "+UserId: string",
    "+Title: string",
    "+Category: string",
    "+Time: string",
    "+IsCompleted: bool"
) @(
    "+ToggleCompleted(): void",
    "+SetReminder(): void",
    "+ToMap(): Map"
)

# Subclasses of DailyRoutine (Inheritance like Checking & Savings in photo!)
# 3. MorningRoutine
$cMorning = Draw-UmlClass 730 220 190 "MorningRoutine" @(
    "+SunscreenSPF: int",
    "+StepOrder: int"
) @(
    "+ApplyMorningSteps(): void"
)

# 4. NightRoutine
$cNight = Draw-UmlClass 730 380 190 "NightRoutine" @(
    "+DoubleCleanse: bool",
    "+StepOrder: int"
) @(
    "+ApplyNightSteps(): void"
)

# 5. Product Class (Top)
$cProduct = Draw-UmlClass 400 40 230 "Product" @(
    "+Id: int",
    "+Name: string",
    "+Brand: string",
    "+Price: double",
    "+Category: string",
    "+Rating: double"
) @(
    "+GetFormattedPrice(): string",
    "+ToggleFavorite(): void",
    "+FromJson(): Product"
)

# 6. FavoriteProduct (Top Right)
$cFav = Draw-UmlClass 730 50 190 "FavoriteProduct" @(
    "+Id: string",
    "+UserId: string",
    "+ProductId: int",
    "+SavedAt: DateTime"
) @(
    "+SaveToHive(): void",
    "+Remove(): void"
)

# 7. BeautyStore Class (Top Left)
$cStore = Draw-UmlClass 70 40 230 "BeautyStore" @(
    "+Id: string",
    "+Name: string",
    "+Address: string",
    "+Latitude: double",
    "+Longitude: double",
    "+Rating: double"
) @(
    "+CalculateDistance(): double",
    "+OpenInMap(): void"
)

# 8. GiveawayTicket (Bottom Center)
$cGiveaway = Draw-UmlClass 400 570 230 "GiveawayTicket" @(
    "+TicketNumber: string",
    "+UserId: string",
    "+ClaimedAt: DateTime",
    "+IsWinner: bool"
) @(
    "+ClaimTicket(): void",
    "+VerifyProof(): bool"
)

# 9. BlockchainBlock (Bottom Right)
$cBlock = Draw-UmlClass 730 570 200 "BlockchainBlock" @(
    "+Index: int",
    "+Timestamp: DateTime",
    "+WinnerTicket: string",
    "+PreviousHash: string",
    "+Hash: string",
    "+Nonce: int"
) @(
    "+CalculateHash(): string",
    "+IsValid(): bool"
)

# 10. AiChatMessage (Bottom Left)
$cAi = Draw-UmlClass 70 600 230 "AiChatMessage" @(
    "+Id: string",
    "+UserId: string",
    "+Text: string",
    "+IsUser: bool",
    "+ImageUrl: string",
    "+Timestamp: DateTime"
) @(
    "+SendPrompt(): void",
    "+ToMap(): Map"
)

# =========================================================================
# DRAW ASSOCIATIONS & CARDINALITIES
# =========================================================================

# 1. User to BeautyStore (Vertical)
$g.DrawLine($penBlack15, ($cUser.X + 80), $cUser.Y, ($cStore.X + 80), ($cStore.Y + $cStore.H))
$g.DrawString("+1", $fontCard, $brushBlack, ($cUser.X + 85), ($cUser.Y - 18))
$g.DrawString("+0..*", $fontCard, $brushBlack, ($cStore.X + 85), ($cStore.Y + $cStore.H + 5))

# 2. User to AiChatMessage (Vertical)
$g.DrawLine($penBlack15, ($cUser.X + 80), ($cUser.Y + $cUser.H), ($cAi.X + 80), $cAi.Y)
$g.DrawString("+1", $fontCard, $brushBlack, ($cUser.X + 85), ($cUser.Y + $cUser.H + 5))
$g.DrawString("+0..*", $fontCard, $brushBlack, ($cAi.X + 85), ($cAi.Y - 18))

# 3. User to DailyRoutine (Horizontal)
$g.DrawLine($penBlack15, ($cUser.X + $cUser.W), ($cUser.Y + 60), $cRoutine.X, ($cRoutine.Y + 60))
$g.DrawString("+1", $fontCard, $brushBlack, ($cUser.X + $cUser.W + 8), ($cUser.Y + 42))
$g.DrawString("+1..*", $fontCard, $brushBlack, ($cRoutine.X - 35), ($cRoutine.Y + 42))

# 4. User to Product (Diagonal-ish / Step line)
$pX1 = $cUser.X + $cUser.W
$pY1 = $cUser.Y + 25
$pX2 = $cProduct.X
$pY2 = $cProduct.Y + 110
$g.DrawLine($penBlack15, $pX1, $pY1, 350, $pY1)
$g.DrawLine($penBlack15, 350, $pY1, 350, $pY2)
$g.DrawLine($penBlack15, 350, $pY2, $pX2, $pY2)
$g.DrawString("+1", $fontCard, $brushBlack, ($pX1 + 5), ($pY1 - 16))
$g.DrawString("+0..*", $fontCard, $brushBlack, ($pX2 - 35), ($pY2 - 16))

# 5. Product to FavoriteProduct (Horizontal)
$g.DrawLine($penBlack15, ($cProduct.X + $cProduct.W), ($cProduct.Y + 60), $cFav.X, ($cFav.Y + 60))
$g.DrawString("+1", $fontCard, $brushBlack, ($cProduct.X + $cProduct.W + 6), ($cProduct.Y + 44))
$g.DrawString("+0..*", $fontCard, $brushBlack, ($cFav.X - 35), ($cFav.Y + 44))

# 6. User to GiveawayTicket (Step line)
$gX1 = $cUser.X + $cUser.W
$gY1 = $cUser.Y + $cUser.H - 30
$gX2 = $cGiveaway.X
$gY2 = $cGiveaway.Y + 50
$g.DrawLine($penBlack15, $gX1, $gY1, 350, $gY1)
$g.DrawLine($penBlack15, 350, $gY1, 350, $gY2)
$g.DrawLine($penBlack15, 350, $gY2, $gX2, $gY2)
$g.DrawString("+1", $fontCard, $brushBlack, ($gX1 + 5), ($gY1 - 16))
$g.DrawString("+0..*", $fontCard, $brushBlack, ($gX2 - 35), ($gY2 - 16))

# 7. GiveawayTicket to BlockchainBlock (Horizontal)
$g.DrawLine($penBlack15, ($cGiveaway.X + $cGiveaway.W), ($cGiveaway.Y + 60), $cBlock.X, ($cBlock.Y + 60))
$g.DrawString("+1", $fontCard, $brushBlack, ($cGiveaway.X + $cGiveaway.W + 6), ($cGiveaway.Y + 44))
$g.DrawString("+1", $fontCard, $brushBlack, ($cBlock.X - 25), ($cBlock.Y + 44))

# =========================================================================
# DRAW INHERITANCE (HOLLOW TRIANGLE ARROWS)
# MorningRoutine & NightRoutine -> DailyRoutine (Exactly like Checking/Savings -> Account in photo!)
# =========================================================================
function Draw-InheritanceArrow ($startX, $startY, $endX, $endY) {
    # Line with step
    $midX = $startX - 40
    $g.DrawLine($penBlack15, $startX, $startY, $midX, $startY)
    $g.DrawLine($penBlack15, $midX, $startY, $midX, $endY)
    $g.DrawLine($penBlack15, $midX, $endY, ($endX + 16), $endY)
    
    # Hollow triangle at target ($endX, $endY)
    $triangle = New-Object System.Drawing.Drawing2D.GraphicsPath
    $triangle.AddLine($endX, $endY, ($endX + 16), ($endY - 9))
    $triangle.AddLine(($endX + 16), ($endY - 9), ($endX + 16), ($endY + 9))
    $triangle.CloseFigure()
    $g.FillPath($brushWhite, $triangle)
    $g.DrawPath($penBlack15, $triangle)
    $triangle.Dispose()
}

Draw-InheritanceArrow $cMorning.X ($cMorning.Y + 45) ($cRoutine.X + $cRoutine.W) ($cRoutine.Y + 50)
Draw-InheritanceArrow $cNight.X ($cNight.Y + 45) ($cRoutine.X + $cRoutine.W) ($cRoutine.Y + 95)

# Caption at bottom
$g.DrawString("Gambar 3.16 Class Diagram Sistem Mirrora", $fontCaption, $brushBlack, ($w / 2), ($h - 35), $sfCenter)

$bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "Class diagram generated at $outputPath"
