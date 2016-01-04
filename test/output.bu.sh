. update-website.sh
init

bu_assert "output output" "output"

tmp="$(echo.Red 'Red warn output')"
bu_assert "output Warn 'Red warn output'" "$tmp"

tmp="$(echo.Green 'Green success output')"
bu_assert "output Success 'Green success output'" "$tmp"

tmp="$(echo.Cyan 'Cyan info output')"
bu_assert "output Info 'Cyan info output'" "$tmp"

