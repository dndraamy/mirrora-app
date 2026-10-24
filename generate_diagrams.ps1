Add-Type -AssemblyName System.Drawing

function Create-UseCaseDiagram1Actor {
    param([string]$outputPath)
    
    $width = 1100
    $height = 860
    $bmp = New-Object System.Drawing.Bitmap $width, $height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::White)

    $penBlack = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)
    $penThin = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 1.8)
    $penBox = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)
    $brushBlack = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
    $brushOval = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255))

    $fontTitle = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
    $fontSub = New-Object System.Drawing.Font("Arial", 10.5, [System.Drawing.FontStyle]::Italic)
    $fontActor = New-Object System.Drawing.Font("Arial", 13, [System.Drawing.FontStyle]::Bold)
    $fontText = New-Object System.Drawing.Font("Arial", 10.5, [System.Drawing.FontStyle]::Regular)

    $sfCenter = New-Object System.Drawing.StringFormat
    $sfCenter.Alignment = [System.Drawing.StringAlignment]::Center
    $sfCenter.LineAlignment = [System.Drawing.StringAlignment]::Center

    # Box
    $boxX = 260
    $boxY = 40
    $boxW = 790
    $boxH = 780
    $g.DrawRectangle($penBox, $boxX, $boxY, $boxW, $boxH)
    $g.DrawString("«mobile app»", $fontSub, $brushBlack, ($boxX + 25), ($boxY + 16))
    $g.DrawString("Mirrora App", $fontTitle, $brushBlack, ($boxX + 25), ($boxY + 34))

    # Stickman Actor (User)
    $ax = 120
    $ay = 410

    # Head
    $g.DrawEllipse($penBlack, ($ax - 26), ($ay - 110), 52, 52)
    # Body
    $g.DrawLine($penBlack, $ax, ($ay - 58), $ax, ($ay + 25))
    # Arms
    $g.DrawLine($penBlack, ($ax - 40), ($ay - 20), $ax, ($ay - 35))
    $g.DrawLine($penBlack, $ax, ($ay - 35), ($ax + 40), ($ay - 20))
    # Legs
    $g.DrawLine($penBlack, $ax, ($ay + 25), ($ax - 30), ($ay + 95))
    $g.DrawLine($penBlack, $ax, ($ay + 25), ($ax + 30), ($ay + 95))
    # Label
    $g.DrawString("User`n(Pengguna)", $fontActor, $brushBlack, $ax, ($ay + 125), $sfCenter)

    # Use Cases (staggered slightly like Image 1)
    $items = @(
        @{ T = "Auth (Login, Register & Biometrik)"; X = 320; Y = 110 },
        @{ T = "Konsultasi AI Skincare`n(Teks & Unggah Foto)"; X = 580; Y = 185 },
        @{ T = "Mengelola Rutinitas Harian`n(Checklist & Notifikasi)"; X = 340; Y = 280 },
        @{ T = "Melihat & Memfilter`nKatalog Produk Kosmetik"; X = 600; Y = 365 },
        @{ T = "Mencari Toko Terdekat`n(LBS GPS & OpenStreetMap)"; X = 330; Y = 460 },
        @{ T = "Memainkan Minigame Sensor`n(Shake to Pick & Bubble Pop)"; X = 590; Y = 545 },
        @{ T = "Mengikuti Undian Giveaway`n& Cek Bukti Blockchain"; X = 340; Y = 640 },
        @{ T = "Mengelola Profil & Pengaturan"; X = 600; Y = 715 }
    )

    $ovalW = 310
    $ovalH = 68

    # Arrow cap
    $cap = New-Object System.Drawing.Drawing2D.AdjustableArrowCap(4.5, 4.5, $true)
    $penLine = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 1.6)
    $penLine.CustomEndCap = $cap

    foreach ($it in $items) {
        $rect = New-Object System.Drawing.Rectangle $it.X, $it.Y, $ovalW, $ovalH
        $g.FillEllipse($brushOval, $rect)
        $g.DrawEllipse($penBlack, $rect)
        $g.DrawString($it.T, $fontText, $brushBlack, ($it.X + ($ovalW / 2)), ($it.Y + ($ovalH / 2)), $sfCenter)

        # Draw line from actor to oval edge
        $targetX = $it.X
        $targetY = $it.Y + ($ovalH / 2)
        $g.DrawLine($penLine, ($ax + 35), ($ay - 25), $targetX, $targetY)
    }

    $bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

function Create-UseCaseDiagram2Actor {
    param([string]$outputPath)
    
    $width = 1250
    $height = 860
    $bmp = New-Object System.Drawing.Bitmap $width, $height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::White)

    $penBlack = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)
    $penBox = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)
    $brushBlack = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
    $brushOval = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255))

    $fontTitle = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
    $fontSub = New-Object System.Drawing.Font("Arial", 10.5, [System.Drawing.FontStyle]::Italic)
    $fontActor = New-Object System.Drawing.Font("Arial", 12.5, [System.Drawing.FontStyle]::Bold)
    $fontText = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Regular)

    $sfCenter = New-Object System.Drawing.StringFormat
    $sfCenter.Alignment = [System.Drawing.StringAlignment]::Center
    $sfCenter.LineAlignment = [System.Drawing.StringAlignment]::Center

    # Box in Center
    $boxX = 330
    $boxY = 40
    $boxW = 590
    $boxH = 780
    $g.DrawRectangle($penBox, $boxX, $boxY, $boxW, $boxH)
    $g.DrawString("«subsystem»", $fontSub, $brushBlack, ($boxX + 25), ($boxY + 16))
    $g.DrawString("Mirrora App", $fontTitle, $brushBlack, ($boxX + 25), ($boxY + 34))

    # Helper function for stickman
    function Draw-Actor ($cx, $cy, $label) {
        $g.DrawEllipse($penBlack, ($cx - 24), ($cy - 95), 48, 48)
        $g.DrawLine($penBlack, $cx, ($cy - 47), $cx, ($cy + 20))
        $g.DrawLine($penBlack, ($cx - 35), ($cy - 15), $cx, ($cy - 28))
        $g.DrawLine($penBlack, $cx, ($cy - 28), ($cx + 35), ($cy - 15))
        $g.DrawLine($penBlack, $cx, ($cy + 20), ($cx - 26), ($cy + 80))
        $g.DrawLine($penBlack, $cx, ($cy + 20), ($cx + 26), ($cy + 80))
        $g.DrawString($label, $fontActor, $brushBlack, $cx, ($cy + 105), $sfCenter)
    }

    # Left Actor 1: User
    Draw-Actor 140 280 "User`n(Pengguna)"

    # Left Actor 2: Admin
    Draw-Actor 140 640 "Admin`n(Owner)"

    # Right Actor: External System
    Draw-Actor 1090 380 "Sistem Eksternal`n(Gemini AI & Supabase)"

    # Vertical stacked ovals
    $items = @(
        @{ T = "Auth (Login, Register & Biometrik)"; Ext = $true },
        @{ T = "Konsultasi AI Skincare (Teks & Foto)"; Ext = $true },
        @{ T = "Mengelola Rutinitas Harian & Notifikasi"; Ext = $false },
        @{ T = "Melihat & Memfilter Katalog Kosmetik"; Ext = $true },
        @{ T = "Mencari Toko Terdekat (LBS/GPS)"; Ext = $true },
        @{ T = "Memainkan Minigame Sensor (Shake & Sound)"; Ext = $false },
        @{ T = "Mengikuti Giveaway & Cek Blockchain"; Ext = $true },
        @{ T = "Kelola Pemenang & Status Giveaway"; Ext = $true }
    )

    $ovalW = 380
    $ovalH = 62
    $ovalX = $boxX + (($boxW - $ovalW) / 2)
    $startY = 100
    $gapY = 88

    $penLine = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 1.5)

    for ($i = 0; $i -lt $items.Count; $i++) {
        $curY = $startY + ($i * $gapY)
        $rect = New-Object System.Drawing.Rectangle $ovalX, $curY, $ovalW, $ovalH
        $g.FillEllipse($brushOval, $rect)
        $g.DrawEllipse($penBlack, $rect)
        $g.DrawString($items[$i].T, $fontText, $brushBlack, ($ovalX + ($ovalW / 2)), ($curY + ($ovalH / 2)), $sfCenter)

        $leftTargetX = $ovalX
        $targetY = $curY + ($ovalH / 2)
        $rightTargetX = $ovalX + $ovalW

        if ($i -lt 7) {
            # User connects to top 7
            $g.DrawLine($penLine, 175, 270, $leftTargetX, $targetY)
        }
        if ($i -eq 0 -or $i -eq 7) {
            # Admin connects to Auth & Kelola Pemenang
            $g.DrawLine($penLine, 175, 630, $leftTargetX, $targetY)
        }
        if ($items[$i].Ext) {
            # External System connects to cloud/API items
            $g.DrawLine($penLine, 1055, 370, $rightTargetX, $targetY)
        }
    }

    $bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

Create-UseCaseDiagram1Actor "c:\src\vscode_flutter\mirrora\mirrora-app\use_case_diagram_mirrora_1_actor.png"
Create-UseCaseDiagram2Actor "c:\src\vscode_flutter\mirrora\mirrora-app\use_case_diagram_mirrora_2_actor.png"

Write-Host "Both diagrams successfully generated."
