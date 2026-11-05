param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-AuroraRingBitmap {
    param([Parameter(Mandatory)][int]$Size)

    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

        $edge = [single][Math]::Max(0.5, $Size * 0.018)
        $disc = [System.Drawing.RectangleF]::new($edge, $edge, [single]($Size - 2 * $edge), [single]($Size - 2 * $edge))
        $gradient = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            $disc,
            [System.Drawing.Color]::FromArgb(255, 91, 222, 199),
            [System.Drawing.Color]::FromArgb(255, 166, 153, 239),
            42.0
        )
        try {
            $blend = [System.Drawing.Drawing2D.ColorBlend]::new(3)
            $blend.Colors = [System.Drawing.Color[]]@(
                [System.Drawing.Color]::FromArgb(255, 91, 222, 199),
                [System.Drawing.Color]::FromArgb(255, 119, 201, 246),
                [System.Drawing.Color]::FromArgb(255, 166, 153, 239)
            )
            $blend.Positions = [single[]]@(0.0, 0.56, 1.0)
            $gradient.InterpolationColors = $blend
            $graphics.FillEllipse($gradient, $disc)
        }
        finally {
            $gradient.Dispose()
        }

        if ($Size -ge 32) {
            $glowRect = [System.Drawing.RectangleF]::new(
                [single]($Size * 0.19),
                [single]($Size * 0.17),
                [single]($Size * 0.62),
                [single]($Size * 0.62)
            )
            $glow = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(43, 239, 253, 255))
            try { $graphics.FillEllipse($glow, $glowRect) }
            finally { $glow.Dispose() }
        }

        $ringInset = [single]($Size * 0.085)
        $ringWidth = [single][Math]::Max(1.0, $Size * 0.027)
        $ringPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(210, 255, 255, 255), $ringWidth)
        try {
            $graphics.DrawEllipse(
                $ringPen,
                [System.Drawing.RectangleF]::new(
                    $ringInset,
                    $ringInset,
                    [single]($Size - 2 * $ringInset),
                    [single]($Size - 2 * $ringInset)
                )
            )
        }
        finally {
            $ringPen.Dispose()
        }

        $fontSize = [single]($Size * 0.56)
        $font = [System.Drawing.Font]::new('Arial Black', $fontSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $textBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 13, 49, 91))
        $format = [System.Drawing.StringFormat]::new()
        try {
            $format.Alignment = [System.Drawing.StringAlignment]::Center
            $format.LineAlignment = [System.Drawing.StringAlignment]::Center
            $format.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
            $graphics.DrawString(
                'Q',
                $font,
                $textBrush,
                [System.Drawing.RectangleF]::new(
                    [single](-$Size * 0.018),
                    [single](-$Size * 0.035),
                    [single]$Size,
                    [single]$Size
                ),
                $format
            )
        }
        finally {
            $format.Dispose()
            $textBrush.Dispose()
            $font.Dispose()
        }
    }
    finally {
        $graphics.Dispose()
    }
    return $bitmap
}

function Save-AuroraRingPng {
    param(
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][int]$Size
    )
    $bitmap = New-AuroraRingBitmap -Size $Size
    try { $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png) }
    finally { $bitmap.Dispose() }
}

function Save-AuroraRingIco {
    param([Parameter(Mandatory)][string]$OutputPath)

    $sizes = @(16, 20, 24, 32, 40, 48, 64, 128, 256)
    $frames = foreach ($size in $sizes) {
        $bitmap = New-AuroraRingBitmap -Size $size
        $stream = [System.IO.MemoryStream]::new()
        try {
            $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
            [pscustomobject]@{ Size = $size; Bytes = $stream.ToArray() }
        }
        finally {
            $stream.Dispose()
            $bitmap.Dispose()
        }
    }

    $file = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    $writer = [System.IO.BinaryWriter]::new($file)
    try {
        $writer.Write([uint16]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]$frames.Count)
        $offset = 6 + 16 * $frames.Count
        foreach ($frame in $frames) {
            $writer.Write([byte]($(if ($frame.Size -ge 256) { 0 } else { $frame.Size })))
            $writer.Write([byte]($(if ($frame.Size -ge 256) { 0 } else { $frame.Size })))
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([uint16]1)
            $writer.Write([uint16]32)
            $writer.Write([uint32]$frame.Bytes.Length)
            $writer.Write([uint32]$offset)
            $offset += $frame.Bytes.Length
        }
        foreach ($frame in $frames) { $writer.Write([byte[]]$frame.Bytes) }
    }
    finally {
        $writer.Dispose()
        $file.Dispose()
    }
}

$pngTargets = @(
    @{ Path = 'CanvasWeb\Assets\qv-canvas.png'; Size = 128 },
    @{ Path = 'CanvasWeb\web\assets\qv-canvas.png'; Size = 96 },
    @{ Path = 'xlquerycode\Resources\QRIcon.png'; Size = 96 },
    @{ Path = 'documentation\assets\images\qanvas-logo.png'; Size = 128 }
)
$icoTargets = @(
    'CanvasWeb\Assets\qv-canvas.ico',
    'XlQueryCanvasApp\qanvas.ico',
    'XlQueryCanvasApp\qanvas_icon.ico'
)

foreach ($target in $pngTargets) {
    Save-AuroraRingPng -OutputPath (Join-Path $RepositoryRoot $target.Path) -Size $target.Size
}
foreach ($target in $icoTargets) {
    Save-AuroraRingIco -OutputPath (Join-Path $RepositoryRoot $target)
}

Write-Host "Generated Aurora Ring icons: $($pngTargets.Count) PNG and $($icoTargets.Count) ICO files."
