# One mark, rendered at native Windows icon sizes. No external drawing runtime.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectDir = Split-Path $PSScriptRoot -Parent
$frames = @()
foreach ($size in @(16,20,24,32,40,48,64,128,256)) {
    $renderSize = $size * 4
    $render = [Drawing.Bitmap]::new($renderSize,$renderSize,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($render)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([Drawing.Color]::Transparent)
    $graphics.ScaleTransform(($renderSize / 256.0),($renderSize / 256.0))
    $path = [Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddArc(8,8,108,108,180,90)
    $path.AddArc(140,8,108,108,270,90)
    $path.AddArc(140,140,108,108,0,90)
    $path.AddArc(8,140,108,108,90,90)
    $path.CloseFigure()
    $tile = [Drawing.Drawing2D.LinearGradientBrush]::new([Drawing.Rectangle]::new(8,8,240,240),[Drawing.ColorTranslator]::FromHtml('#193539'),[Drawing.ColorTranslator]::FromHtml('#081416'),45.0)
    $edge = [Drawing.Pen]::new([Drawing.Color]::FromArgb(102,30,202,183),2)
    $graphics.FillPath($tile,$path)
    $graphics.DrawPath($edge,$path)
    # The V has more ink in its upper arms. Centre its visual mass vertically,
    # and preserve mirrored X coordinates around 128 at every Windows size.
    $graphics.TranslateTransform(0,9)
    $points = [Drawing.PointF[]]@(
        [Drawing.PointF]::new(38,74),[Drawing.PointF]::new(98,74),[Drawing.PointF]::new(128,128),
        [Drawing.PointF]::new(158,74),[Drawing.PointF]::new(218,74),[Drawing.PointF]::new(143.6,182),[Drawing.PointF]::new(112.4,182)
    )
    $ink = [Drawing.Drawing2D.LinearGradientBrush]::new([Drawing.Rectangle]::new(38,74,180,108),[Drawing.ColorTranslator]::FromHtml('#eaf3ef'),[Drawing.ColorTranslator]::FromHtml('#52d887'),90.0)
    $accent = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#1ecab7'))
    $graphics.FillPolygon($ink,$points)
    $graphics.FillPolygon($accent,[Drawing.PointF[]]@([Drawing.PointF]::new(112.4,74),[Drawing.PointF]::new(143.6,74),[Drawing.PointF]::new(128,101.6)))
    $bitmap = [Drawing.Bitmap]::new($size,$size,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $output = [Drawing.Graphics]::FromImage($bitmap)
    $output.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
    $output.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $output.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $output.DrawImage($render,[Drawing.Rectangle]::new(0,0,$size,$size),0,0,$renderSize,$renderSize,[Drawing.GraphicsUnit]::Pixel)
    $stream = [IO.MemoryStream]::new()
    $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
    $frames += @{ Size=$size; Bytes=$stream.ToArray() }
    if ($size -eq 256) { $bitmap.Save((Join-Path $projectDir 'public\vyrax-icon.png'),[Drawing.Imaging.ImageFormat]::Png) }
    $stream.Dispose(); $ink.Dispose(); $accent.Dispose(); $tile.Dispose(); $edge.Dispose(); $path.Dispose(); $graphics.Dispose(); $output.Dispose(); $render.Dispose(); $bitmap.Dispose()
}
$file = [IO.File]::Create((Join-Path $projectDir 'native\Vyrax.ico'))
$writer = [IO.BinaryWriter]::new($file)
try {
    $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$frames.Count)
    $offset = 6 + 16 * $frames.Count
    foreach ($frame in $frames) {
        $dimension = if ($frame.Size -eq 256) { 0 } else { $frame.Size }
        $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
        $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([uint16]1); $writer.Write([uint16]32)
        $writer.Write([uint32]$frame.Bytes.Length); $writer.Write([uint32]$offset)
        $offset += $frame.Bytes.Length
    }
    foreach ($frame in $frames) { $writer.Write([byte[]]$frame.Bytes) }
} finally { $writer.Dispose(); $file.Dispose() }
Write-Output 'Vyrax.ico: 9 sizes (16-256 px)'
