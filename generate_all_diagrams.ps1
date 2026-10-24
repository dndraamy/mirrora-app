Add-Type -AssemblyName System.Drawing

$outputDir = "c:\src\vscode_flutter\mirrora\mirrora-app\diagrams"
if (!(Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force }

$penBlack2 = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)
$penBlack15 = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 1.5)
$penBlack1 = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 1.2)
$penDashed = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 1.2)
$penDashed.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash

$brushBlack = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
$brushWhite = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$brushGray = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 245, 245))

$fontCaption = New-Object System.Drawing.Font("Times New Roman", 13, [System.Drawing.FontStyle]::Regular)
$fontHeader = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
$fontBox = New-Object System.Drawing.Font("Arial", 9.5, [System.Drawing.FontStyle]::Regular)
$fontBoxBold = New-Object System.Drawing.Font("Arial", 9.5, [System.Drawing.FontStyle]::Bold)
$fontMsg = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Regular)

$sfCenter = New-Object System.Drawing.StringFormat
$sfCenter.Alignment = [System.Drawing.StringAlignment]::Center
$sfCenter.LineAlignment = [System.Drawing.StringAlignment]::Center

$sfLeft = New-Object System.Drawing.StringFormat
$sfLeft.Alignment = [System.Drawing.StringAlignment]::Near
$sfLeft.LineAlignment = [System.Drawing.StringAlignment]::Center

$arrowCap = New-Object System.Drawing.Drawing2D.AdjustableArrowCap(4.5, 4.5, $true)
$penArrow = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 1.4)
$penArrow.CustomEndCap = $arrowCap

$penDashArrow = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 1.2)
$penDashArrow.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$penDashArrow.CustomEndCap = $arrowCap

# =========================================================================
# HELPER: DRAW ROUNDED RECT
# =========================================================================
function Draw-RoundedRect ($g, $pen, $brush, $x, $y, $w, $h, $r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc(($x + $w - $d), $y, $d, $d, 270, 90)
    $path.AddArc(($x + $w - $d), ($y + $h - $d), $d, $d, 0, 90)
    $path.AddArc($x, ($y + $h - $d), $d, $d, 90, 90)
    $path.CloseFigure()
    if ($brush) { $g.FillPath($brush, $path) }
    if ($pen) { $g.DrawPath($pen, $path) }
    $path.Dispose()
}

# =========================================================================
# BUILD ACTIVITY DIAGRAM
# =========================================================================
function Generate-ActivityDiagram {
    param(
        [string]$fileName,
        [string]$featureTitle,
        [string]$captionText,
        [array]$steps # array of @{ Lane='User'|'Sistem'; Text='...'; Fork=$false; Branch=$null }
    )
    
    $w = 720
    $totalSteps = $steps.Count
    $h = 160 + ($totalSteps * 82) + 100
    
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::White)
    
    # Outer Swimlane Frame
    $fx = 50; $fy = 40; $fw = 620; $fh = $h - 100
    $g.DrawRectangle($penBlack2, $fx, $fy, $fw, $fh)
    
    # Top title bar
    $titleH = 34
    $g.DrawLine($penBlack15, $fx, ($fy + $titleH), ($fx + $fw), ($fy + $titleH))
    $g.DrawString($featureTitle, $fontHeader, $brushBlack, ($fx + ($fw / 2)), ($fy + ($titleH / 2)), $sfCenter)
    
    # Column Header (User | Sistem)
    $headerH = 30
    $midX = $fx + ($fw / 2)
    $g.DrawLine($penBlack15, $fx, ($fy + $titleH + $headerH), ($fx + $fw), ($fy + $titleH + $headerH))
    $g.DrawLine($penBlack15, $midX, ($fy + $titleH), $midX, ($fy + $fh))
    
    $g.DrawString("User", $fontHeader, $brushBlack, ($fx + (($fw / 4))), ($fy + $titleH + ($headerH / 2)), $sfCenter)
    $g.DrawString("Sistem", $fontHeader, $brushBlack, ($midX + (($fw / 4))), ($fy + $titleH + ($headerH / 2)), $sfCenter)
    
    # Start Node
    $startY = $fy + $titleH + $headerH + 25
    $userColCenter = $fx + ($fw / 4)
    $sysColCenter = $midX + ($fw / 4)
    
    $g.FillEllipse($brushBlack, ($userColCenter - 13), $startY, 26, 26)
    
    $lastX = $userColCenter
    $lastY = $startY + 26
    
    $boxW = 200
    $boxH = 50
    $boxR = 12
    $curY = $startY + 50
    
    for ($i = 0; $i -lt $steps.Count; $i++) {
        $st = $steps[$i]
        $targetColX = if ($st.Lane -eq 'User') { $userColCenter } else { $sysColCenter }
        $boxLeft = $targetColX - ($boxW / 2)
        
        # Connect from last position
        $entryY = $curY
        if ($lastX -eq $targetColX) {
            $g.DrawLine($penArrow, $lastX, $lastY, $targetColX, $entryY)
        } else {
            # Step connector (L-shape or Z-shape)
            $midY = $lastY + (($entryY - $lastY) / 2)
            $g.DrawLine($penBlack15, $lastX, $lastY, $lastX, $midY)
            $g.DrawLine($penBlack15, $lastX, $midY, $targetColX, $midY)
            $g.DrawLine($penArrow, $targetColX, $midY, $targetColX, $entryY)
        }
        
        # Draw Activity Box
        Draw-RoundedRect $g $penBlack15 $brushWhite $boxLeft $curY $boxW $boxH $boxR
        $g.DrawString($st.Text, $fontBox, $brushBlack, $targetColX, ($curY + ($boxH / 2)), $sfCenter)
        
        $lastX = $targetColX
        $lastY = $curY + $boxH
        $curY += 78
    }
    
    # Final Bullseye Node
    $endNodeY = $curY + 10
    $g.DrawLine($penArrow, $lastX, $lastY, $lastX, $endNodeY)
    
    $g.DrawEllipse($penBlack2, ($lastX - 16), $endNodeY, 32, 32)
    $g.FillEllipse($brushBlack, ($lastX - 10), ($endNodeY + 6), 20, 20)
    
    # Caption at bottom
    $captionY = $h - 38
    $g.DrawString($captionText, $fontCaption, $brushBlack, ($w / 2), $captionY, $sfCenter)
    
    $fullPath = Join-Path $outputDir $fileName
    $bmp.Save($fullPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host "Generated $fileName"
}

# =========================================================================
# BUILD SEQUENCE DIAGRAM
# =========================================================================
function Generate-SequenceDiagram {
    param(
        [string]$fileName,
        [string]$frameTitle,
        [string]$captionText,
        [array]$lifelines, # e.g. @('Sistem', 'Database')
        [array]$messages   # @{ From=0; To=1; Msg='...'; Return=$false }
    )
    
    $w = 760
    $h = 160 + ($messages.Count * 56) + 90
    
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::White)
    
    # Outer UML Frame
    $fx = 40; $fy = 30; $fw = 680; $fh = $h - 80
    $g.DrawRectangle($penBlack2, $fx, $fy, $fw, $fh)
    
    # Frame Title Tab (Pentagon / folded corner shape)
    $tabW = 220; $tabH = 30; $cut = 12
    $tabPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $tabPath.AddLine($fx, $fy, ($fx + $tabW - $cut), $fy)
    $tabPath.AddLine(($fx + $tabW - $cut), $fy, ($fx + $tabW), ($fy + $cut))
    $tabPath.AddLine(($fx + $tabW), ($fy + $tabH), $fx, ($fy + $tabH))
    $tabPath.CloseFigure()
    $g.DrawPath($penBlack15, $tabPath)
    $g.DrawString($frameTitle, $fontHeader, $brushBlack, ($fx + ($tabW / 2) - 6), ($fy + ($tabH / 2)), $sfCenter)
    
    # Lifeline X positions: User is index 0
    $numCols = 1 + $lifelines.Count
    $colSpacing = ($fw - 120) / ($numCols - 1)
    $colX = @()
    $colX += ($fx + 60)
    for ($k = 0; $k -lt $lifelines.Count; $k++) {
        $colX += ($fx + 60 + (($k + 1) * $colSpacing))
    }
    
    # Stickman Actor at colX[0]
    $ax = $colX[0]; $ay = $fy + 75
    $g.DrawEllipse($penBlack15, ($ax - 12), ($ay - 35), 24, 24)
    $g.DrawLine($penBlack15, $ax, ($ay - 11), $ax, ($ay + 18))
    $g.DrawLine($penBlack15, ($ax - 18), ($ay - 2), ($ax + 18), ($ay - 2))
    $g.DrawLine($penBlack15, $ax, ($ay + 18), ($ax - 14), ($ay + 42))
    $g.DrawLine($penBlack15, $ax, ($ay + 18), ($ax + 14), ($ay + 42))
    
    # Lifeline boxes for other participants
    $boxTopY = $fy + 55
    $boxW = 110; $boxH = 38
    for ($k = 0; $k -lt $lifelines.Count; $k++) {
        $bx = $colX[$k + 1] - ($boxW / 2)
        $g.DrawRectangle($penBlack15, $bx, $boxTopY, $boxW, $boxH)
        $g.DrawString($lifelines[$k], $fontHeader, $brushBlack, $colX[$k + 1], ($boxTopY + ($boxH / 2)), $sfCenter)
    }
    
    # Dashed Lifeline Lines
    $lifeStartY = $fy + 125
    $lifeEndY = $fy + $fh - 30
    for ($k = 0; $k -lt $colX.Count; $k++) {
        $g.DrawLine($penDashed, $colX[$k], $lifeStartY, $colX[$k], $lifeEndY)
    }
    
    # Activation Bars
    $actW = 14
    for ($k = 0; $k -lt $colX.Count; $k++) {
        $actX = $colX[$k] - ($actW / 2)
        $g.FillRectangle($brushWhite, $actX, $lifeStartY, $actW, ($lifeEndY - $lifeStartY))
        $g.DrawRectangle($penBlack1, $actX, $lifeStartY, $actW, ($lifeEndY - $lifeStartY))
    }
    
    # Draw Messages
    $msgY = $lifeStartY + 25
    for ($m = 0; $m -lt $messages.Count; $m++) {
        $msg = $messages[$m]
        $x1 = $colX[$msg.From]
        $x2 = $colX[$msg.To]
        
        $penToUse = if ($msg.Return) { $penDashArrow } else { $penArrow }
        
        # Adjust for activation bar width
        $startX = if ($x1 -lt $x2) { $x1 + ($actW / 2) } else { $x1 - ($actW / 2) }
        $endX = if ($x1 -lt $x2) { $x2 - ($actW / 2) } else { $x2 + ($actW / 2) }
        
        $g.DrawLine($penToUse, $startX, $msgY, $endX, $msgY)
        
        # Label above arrow
        $labelX = $startX + (($endX - $startX) / 2)
        $labelY = $msgY - 10
        $g.DrawString($msg.Msg, $fontMsg, $brushBlack, $labelX, $labelY, $sfCenter)
        
        $msgY += 56
    }
    
    # Caption
    $captionY = $h - 28
    $g.DrawString($captionText, $fontCaption, $brushBlack, ($w / 2), $captionY, $sfCenter)
    
    $fullPath = Join-Path $outputDir $fileName
    $bmp.Save($fullPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host "Generated $fileName"
}

# =========================================================================
# 1. LOGIN DAN REGISTRASI
# =========================================================================
Generate-ActivityDiagram "act_01_login_registrasi.png" "Login dan Registrasi" "Gambar 3.2 Activity Diagram Login dan Registrasi" @(
    @{ Lane='User'; Text="Membuka Aplikasi Mirrora" },
    @{ Lane='Sistem'; Text="Menampilkan Form Auth" },
    @{ Lane='User'; Text="Input Email dan Password" },
    @{ Lane='Sistem'; Text="Enkripsi Sandi via BCrypt" },
    @{ Lane='Sistem'; Text="Validasi Akun ke Database" },
    @{ Lane='Sistem'; Text="Simpan Token ke Secure Storage" },
    @{ Lane='Sistem'; Text="Menampilkan Halaman Utama" }
)

Generate-SequenceDiagram "seq_01_login_registrasi.png" "Login & Registrasi" "Gambar 3.9 Sequence Diagram Login dan Registrasi" @('Sistem (Auth)', 'Database') @(
    @{ From=0; To=1; Msg="inputKredensial(email, pass)"; Return=$false },
    @{ From=1; To=2; Msg="queryUser(email)"; Return=$false },
    @{ From=2; To=1; Msg="userData (hashBCrypt)"; Return=$true },
    @{ From=1; To=1; Msg="verifyPassword()"; Return=$false },
    @{ From=1; To=0; Msg="loginSuccess (sessionToken)"; Return=$true },
    @{ From=0; To=1; Msg="bukaHomeScreen()"; Return=$false }
)

# =========================================================================
# 2. AKTIFKAN BIOMETRIK
# =========================================================================
Generate-ActivityDiagram "act_02_aktifkan_biometrik.png" "Aktifkan Biometrik" "Gambar 3.3 Activity Diagram Aktifkan Biometrik" @(
    @{ Lane='User'; Text="Membuka Menu Pengaturan" },
    @{ Lane='Sistem'; Text="Menampilkan Opsi Biometrik" },
    @{ Lane='User'; Text="Mengaktifkan Toggle Biometrik" },
    @{ Lane='Sistem'; Text="Mengecek Sensor Sidik Jari/Wajah" },
    @{ Lane='User'; Text="Memindai Sidik Jari pada Sensor" },
    @{ Lane='Sistem'; Text="Validasi Sensor Berhasil" },
    @{ Lane='Sistem'; Text="Simpan Status di Secure Storage" }
)

Generate-SequenceDiagram "seq_02_aktifkan_biometrik.png" "Aktifkan Biometrik" "Gambar 3.10 Sequence Diagram Aktifkan Biometrik" @('Sistem (Settings)', 'LocalAuth OS') @(
    @{ From=0; To=1; Msg="toggleBiometrik(true)"; Return=$false },
    @{ From=1; To=2; Msg="canCheckBiometrics()"; Return=$false },
    @{ From=2; To=1; Msg="status (available)"; Return=$true },
    @{ From=1; To=2; Msg="authenticate(Pindai Jari)"; Return=$false },
    @{ From=2; To=0; Msg="promptSensorDialog()"; Return=$true },
    @{ From=0; To=2; Msg="tempelkanSidikJari()"; Return=$false },
    @{ From=2; To=1; Msg="authResult (success)"; Return=$true },
    @{ From=1; To=0; Msg="notifikasiBiometrikAktif()"; Return=$true }
)

# =========================================================================
# 3. ATUR NOTIFIKASI DAILY ROUTINE
# =========================================================================
Generate-ActivityDiagram "act_03_atur_notifikasi.png" "Atur Notifikasi Daily Routine" "Gambar 3.4 Activity Diagram Atur Notifikasi Daily Routine" @(
    @{ Lane='User'; Text="Membuka Menu Daily Routine" },
    @{ Lane='Sistem'; Text="Menampilkan Daftar Jadwal Skincare" },
    @{ Lane='User'; Text="Pilih Jam Pengingat Rutinitas" },
    @{ Lane='Sistem'; Text="Minta Izin Notifikasi Perangkat" },
    @{ Lane='Sistem'; Text="Jadwalkan Alarm via Timezone" },
    @{ Lane='Sistem'; Text="Simpan Konfigurasi ke Hive" },
    @{ Lane='Sistem'; Text="Tampilkan Notifikasi Berhasil Diatur" }
)

Generate-SequenceDiagram "seq_03_atur_notifikasi.png" "Atur Notifikasi Daily Routine" "Gambar 3.11 Sequence Diagram Atur Notifikasi Daily Routine" @('RoutineService', 'NotificationService', 'Local DB (Hive)') @(
    @{ From=0; To=1; Msg="setReminderTime(07:00 Pagi)"; Return=$false },
    @{ From=1; To=2; Msg="scheduleNotification(id, time)"; Return=$false },
    @{ From=2; To=2; Msg="registerTimezoneAlarm()"; Return=$false },
    @{ From=2; To=1; Msg="scheduleSuccess"; Return=$true },
    @{ From=1; To=3; Msg="saveRoutineSchedule(routineData)"; Return=$false },
    @{ From=3; To=1; Msg="dataSaved"; Return=$true },
    @{ From=1; To=0; Msg="tampilkanKonfirmasiTersimpan()"; Return=$true }
)

# =========================================================================
# 4. PENGGUNAAN AI (BEAUTY ASSISTANT)
# =========================================================================
Generate-ActivityDiagram "act_04_penggunaan_ai.png" "Penggunaan AI Beauty Assistant" "Gambar 3.5 Activity Diagram Penggunaan AI" @(
    @{ Lane='User'; Text="Membuka Fitur AI Beauty Assistant" },
    @{ Lane='Sistem'; Text="Menampilkan Antarmuka Konsultasi" },
    @{ Lane='User'; Text="Ketik Keluhan & Unggah Foto Kulit" },
    @{ Lane='Sistem'; Text="Encode Citra ke Base64" },
    @{ Lane='Sistem'; Text="Kirim ke Supabase Edge Function" },
    @{ Lane='Sistem'; Text="Inferensi Model Google Gemini AI" },
    @{ Lane='Sistem'; Text="Simpan Chat & Tampilkan Solusi" }
)

Generate-SequenceDiagram "seq_04_penggunaan_ai.png" "Penggunaan AI Beauty" "Gambar 3.12 Sequence Diagram Penggunaan AI" @('AiService', 'Supabase EdgeFunc', 'Gemini AI API') @(
    @{ From=0; To=1; Msg="kirimPesan(teks, fotoKulit)"; Return=$false },
    @{ From=1; To=2; Msg="postRequest(payloadMultimodal)"; Return=$false },
    @{ From=2; To=2; Msg="injectGeminiApiKey()"; Return=$false },
    @{ From=2; To=3; Msg="generateContent(prompt, img)"; Return=$false },
    @{ From=3; To=2; Msg="hasilAnalisisKulit"; Return=$true },
    @{ From=2; To=1; Msg="200 OK (jawabanRekomendasi)"; Return=$true },
    @{ From=1; To=0; Msg="renderBubblePesanAI()"; Return=$true }
)

# =========================================================================
# 5. UNDIAN GIVEAWAY (SHAKE & BLOCKCHAIN)
# =========================================================================
Generate-ActivityDiagram "act_05_undian_giveaway.png" "Undian Giveaway" "Gambar 3.6 Activity Diagram Undian Giveaway" @(
    @{ Lane='User'; Text="Buka Layar Shake Giveaway" },
    @{ Lane='Sistem'; Text="Mengaktifkan Sensor Akselerometer" },
    @{ Lane='User'; Text="Guncang Perangkat Fisik (Shake)" },
    @{ Lane='Sistem'; Text="Akumulasi Energi Kinetik Guncangan" },
    @{ Lane='Sistem'; Text="Terbitkan Nomor Tiket Giveaway" },
    @{ Lane='Sistem'; Text="Kunci Hash Pemenang ke Blockchain" },
    @{ Lane='Sistem'; Text="Tampilkan Tiket & Bukti SHA-256" }
)

Generate-SequenceDiagram "seq_05_undian_giveaway.png" "Undian Giveaway" "Gambar 3.13 Sequence Diagram Undian Giveaway" @('GiveawayService', 'SimpleBlockchain', 'Database') @(
    @{ From=0; To=1; Msg="shakeCompleted()"; Return=$false },
    @{ From=1; To=1; Msg="generateEntryTicket()"; Return=$false },
    @{ From=1; To=3; Msg="saveParticipant(ticket, user)"; Return=$false },
    @{ From=3; To=1; Msg="ticketSaved (#MIR-1049)"; Return=$true },
    @{ From=1; To=2; Msg="addBlock(winner, ticket)"; Return=$false },
    @{ From=2; To=2; Msg="calculateSHA256Hash()"; Return=$false },
    @{ From=2; To=1; Msg="blockAppended (validHash)"; Return=$true },
    @{ From=1; To=0; Msg="tampilkanCelebrationDialog()"; Return=$true }
)

# =========================================================================
# 6. CARI TOKO TERDEKAT (LBS & OSM)
# =========================================================================
Generate-ActivityDiagram "act_06_cari_toko_terdekat.png" "Cari Toko Terdekat" "Gambar 3.7 Activity Diagram Cari Toko Terdekat" @(
    @{ Lane='User'; Text="Membuka Menu Toko Terdekat" },
    @{ Lane='Sistem'; Text="Minta Izin & Baca Koordinat GPS" },
    @{ Lane='Sistem'; Text="Kirim Kueri ke Overpass OSM API" },
    @{ Lane='Sistem'; Text="Render Peta & Pin Marker Toko" },
    @{ Lane='User'; Text="Pilih Marker Toko Kosmetik" },
    @{ Lane='Sistem'; Text="Tampilkan Lembar Rincian Toko" },
    @{ Lane='User'; Text="Klik Buka Rute di Google Maps" }
)

Generate-SequenceDiagram "seq_06_cari_toko_terdekat.png" "Cari Toko Terdekat" "Gambar 3.14 Sequence Diagram Cari Toko Terdekat" @('LocationService', 'OsmStoreService (API)', 'Peta (FlutterMap)') @(
    @{ From=0; To=1; Msg="getCurrentLocation()"; Return=$false },
    @{ From=1; To=0; Msg="latLongKoordinatUser"; Return=$true },
    @{ From=0; To=2; Msg="fetchNearbyStores(lat, lon)"; Return=$false },
    @{ From=2; To=2; Msg="queryOverpassPOICosmetics()"; Return=$false },
    @{ From=2; To=3; Msg="listBeautyStores"; Return=$true },
    @{ From=3; To=0; Msg="tampilkanMarkerPeta()"; Return=$true },
    @{ From=0; To=3; Msg="klikTokoDanBukaRute()"; Return=$false }
)

# =========================================================================
# 7. TAMBAH PRODUK KE FAVORITE
# =========================================================================
Generate-ActivityDiagram "act_07_tambah_favorite.png" "Tambah Produk ke Favorite" "Gambar 3.8 Activity Diagram Tambah Produk ke Favorite" @(
    @{ Lane='User'; Text="Membuka Katalog & Pilih Produk" },
    @{ Lane='Sistem'; Text="Menampilkan Halaman Detail Produk" },
    @{ Lane='User'; Text="Klik Ikon Hati (Favorite)" },
    @{ Lane='Sistem'; Text="Cek Status Favorit di Hive Box" },
    @{ Lane='Sistem'; Text="Simpan Data Produk ke Favorit" },
    @{ Lane='Sistem'; Text="Ubah Warna Ikon Menjadi Merah" },
    @{ Lane='Sistem'; Text="Tampilkan Pesan Berhasil Disimpan" }
)

Generate-SequenceDiagram "seq_07_tambah_favorite.png" "Tambah Produk Favorite" "Gambar 3.15 Sequence Diagram Tambah Produk ke Favorite" @('ProductDetailScreen', 'FavoritesService', 'Local DB (Hive)') @(
    @{ From=0; To=1; Msg="klikIkonFavorite(product)"; Return=$false },
    @{ From=1; To=2; Msg="toggleFavorite(product)"; Return=$false },
    @{ From=2; To=3; Msg="isProductInBox(id)"; Return=$false },
    @{ From=3; To=2; Msg="status (false)"; Return=$true },
    @{ From=2; To=3; Msg="putProduct(product.id, data)"; Return=$false },
    @{ From=3; To=2; Msg="writeSuccess"; Return=$true },
    @{ From=2; To=1; Msg="stateUpdated (isFavorite=true)"; Return=$true },
    @{ From=1; To=0; Msg="updateIconUI & showSnackBar()"; Return=$true }
)

Write-Host "All 14 diagrams generated successfully!"
