param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\CanvasWeb\web\assets\experience\qvitr')
)

$target = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($target) | Out-Null

$icons = @(
    @{ File = 'qugin.svg'; Name = 'Qugin'; Glyph = 'Q'; Role = '--qreports-accent';   Fallback = '#9EE4D5'; BlendRole = '--qreports-text';     BlendFallback = '#182230'; Blend = 6  },
    @{ File = 'saga.svg';  Name = 'Saga';  Glyph = 'S'; Role = '--qreports-positive'; Fallback = '#78B9F2'; BlendRole = '--qreports-accent';   BlendFallback = '#4F6EE8'; Blend = 18 },
    @{ File = 'kvase.svg'; Name = 'Kvase'; Glyph = '✦'; Role = '--qreports-accent';   Fallback = '#B4A1F2'; BlendRole = '--qreports-negative'; BlendFallback = '#C43D4B'; Blend = 30 },
    @{ File = 'tafla.svg'; Name = 'Tafla'; Glyph = 'T'; Role = '--qreports-accent';   Fallback = '#E4C27B'; BlendRole = '--qreports-positive'; BlendFallback = '#16844A'; Blend = 28 },
    @{ File = 'run.svg';   Name = 'Rún';   Glyph = 'Σ'; Role = '--qreports-negative'; Fallback = '#ECA1AD'; BlendRole = '--qreports-accent';   BlendFallback = '#4F6EE8'; Blend = 14 }
)

foreach ($icon in $icons) {
    $primary = 100 - [int]$icon.Blend
    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-label="$($icon.Name)" style="--qv-icon-accent:color-mix(in srgb,var($($icon.Role),$($icon.Fallback)) $primary%,var($($icon.BlendRole),$($icon.BlendFallback)) $($icon.Blend)%);--qv-icon-surface:var(--qreports-surface,#ffffff);--qv-icon-core:var(--qreports-header,#182230);--qv-icon-text:var(--qreports-header-text,#f4f7fb)">
  <circle cx="256" cy="256" r="226" fill="color-mix(in srgb,var(--qv-icon-accent) 18%,var(--qv-icon-surface))"/>
  <circle cx="256" cy="256" r="218" fill="none" stroke="color-mix(in srgb,var(--qv-icon-accent) 38%,transparent)" stroke-width="18"/>
  <circle cx="256" cy="256" r="192" fill="var(--qv-icon-core)" stroke="var(--qv-icon-accent)" stroke-width="42"/>
  <text x="256" y="278" text-anchor="middle" dominant-baseline="middle" fill="var(--qv-icon-text)" font-family="Segoe UI,Arial,sans-serif" font-size="174" font-weight="800">$($icon.Glyph)</text>
  <circle cx="424" cy="414" r="49" fill="var(--qv-icon-core)"/>
  <circle cx="424" cy="414" r="33" fill="var(--qv-icon-surface)" stroke="var(--qv-icon-accent)" stroke-width="10"/>
</svg>
"@
    $path = Join-Path $target $icon.File
    [IO.File]::WriteAllText($path, $svg.Trim(), [Text.UTF8Encoding]::new($false))
    Write-Output $path
}
