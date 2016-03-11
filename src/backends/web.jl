
# NOTE:  backend should implement `html_body` and `html_head`

# CREDIT: parts of this implementation were inspired by @joshday's PlotlyLocal.jl


function standalone_html(plt::AbstractPlot; title::AbstractString = get(plt.plotargs, :window_title, "Plots.jl"))
    """
    <!DOCTYPE html>
    <html>
        <head>
            <title>$title</title>
            $(html_head(plt))
        </head>
        <body>
            $(html_body(plt))
        </body>
    </html>
    """
end

function open_browser_window(filename::AbstractString)
    @osx_only   return run(`open $(filename)`)
    @linux_only return run(`xdg-open $(filename)`)
    @windows_only return run(`$(ENV["COMSPEC"]) /c start $(filename)`)
    warn("Unknown OS... cannot open browser window.")
end

function standalone_html_window(plt::AbstractPlot; kw...)
    html = standalone_html(plt; kw...)
    # println(html)
    filename = string(tempname(), ".html")
    output = open(filename, "w")
    write(output, html)
    close(output)
    open_browser_window(filename)
end

