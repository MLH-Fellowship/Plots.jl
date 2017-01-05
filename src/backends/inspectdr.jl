
# https://github.com/ma-laforge/InspectDR.jl

#=TODO:
    Tweak scale factor for width & other sizes

Not supported by InspectDR:
    :foreground_color_grid
    :foreground_color_border
    :polar,

Add in functionality to Plots.jl:
    :aspect_ratio,
=#

# ---------------------------------------------------------------------------
#TODO: remove features
const _inspectdr_attr = merge_with_base_supported([
    :annotations,
    :background_color_legend, :background_color_inside, :background_color_outside,
    :foreground_color_grid, :foreground_color_legend, :foreground_color_title,
    :foreground_color_axis, :foreground_color_border, :foreground_color_guide, :foreground_color_text,
    :label,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    :markerstrokestyle, #Causes warning not to have it... what is this?
    :fillcolor, :fillalpha, #:fillrange,
#    :bins, :bar_width, :bar_edges, :bar_position,
    :title, :title_location, :titlefont,
    :window_title,
    :guide, :lims, :scale, #:ticks, :flip, :rotation,
    :tickfont, :guidefont, :legendfont,
    :grid, :legend, #:colorbar,
#    :marker_z,
#    :line_z,
#    :levels,
 #   :ribbon, :quiver, :arrow,
#    :orientation,
    :overwrite_figure,
#    :polar,
#    :normalize, :weights,
#    :contours, :aspect_ratio,
    :match_dimensions,
#    :clims,
#    :inset_subplots,
    :dpi,
#    :colorbar_title,
  ])
const _inspectdr_style = [:auto, :solid, :dash, :dot, :dashdot]
const _inspectdr_seriestype = [
        :path, :scatter, :shape #, :steppre, :steppost
    ]
#see: _allMarkers, _shape_keys
const _inspectdr_marker = Symbol[
    :none, :auto,
    :circle, :rect, :diamond,
    :cross, :xcross,
    :utriangle, :dtriangle, :rtriangle, :ltriangle,
    :pentagon, :hexagon, :heptagon, :octagon,
    :star4, :star5, :star6, :star7, :star8,
    :vline, :hline, :+, :x,
]

const _inspectdr_scale = [:identity, :ln, :log2, :log10]

is_marker_supported(::InspectDRBackend, shape::Shape) = true

#Do we avoid Map to avoid possible pre-comile issues?
function _inspectdr_mapglyph(s::Symbol)
    s == :rect && return :square
    return s
end

function _inspectdr_mapglyph(s::Shape)
    x, y = coords(s)
    return InspectDR.GlyphPolyline(x, y)
end

# py_marker(markers::AVec) = map(py_marker, markers)
function _inspectdr_mapglyph(markers::AVec)
    warn("Vectors of markers are currently unsupported in InspectDR.")
    _inspectdr_mapglyph(markers[1])
end

_inspectdr_mapglyphsize(v::Real) = v
function _inspectdr_mapglyphsize(v::Vector)
    warn("Vectors of marker sizes are currently unsupported in InspectDR.")
    _inspectdr_mapglyphsize(v[1])
end

_inspectdr_mapcolor(v::Colorant) = v
function _inspectdr_mapcolor(g::PlotUtils.ColorGradient)
    warn("Color gradients are currently unsupported in InspectDR.")
    #Pick middle color:
    _inspectdr_mapcolor(g.colors[div(1+end,2)])
end
function _inspectdr_mapcolor(v::AVec)
    warn("Vectors of colors are currently unsupported in InspectDR.")
    #Pick middle color:
    _inspectdr_mapcolor(v[div(1+end,2)])
end

#Hack: suggested point size does not seem adequate relative to plot size, for some reason.
_inspectdr_mapptsize(v) = 1.5*v

function _inspectdr_add_annotations(plot, x, y, val)
    #What kind of annotation is this?
end

#plot::InspectDR.Plot2D
function _inspectdr_add_annotations(plot, x, y, val::PlotText)
    vmap = Dict{Symbol, Symbol}(:top=>:t, :bottom=>:b) #:vcenter
    hmap = Dict{Symbol, Symbol}(:left=>:l, :right=>:r) #:hcenter
    align = Symbol(get(vmap, val.font.valign, :c), get(hmap, val.font.halign, :c))
    fnt = InspectDR.Font(val.font.family, val.font.pointsize,
        color =_inspectdr_mapcolor(val.font.color)
    )
    ann = InspectDR.atext(val.str, x=x, y=y,
        font=fnt, angle=val.font.rotation, align=align
    )
    InspectDR.add(plot, ann)
    return
end

# ---------------------------------------------------------------------------

function _inspectdr_getscale(s::Symbol)
#TODO: Support :asinh, :sqrt
    if :log2 == s
        return InspectDR.AxisScale(:log2)
    elseif :log10 == s
        return InspectDR.AxisScale(:log10)
    elseif :ln == s
        return InspectDR.AxisScale(:ln)
    else #identity
        return InspectDR.AxisScale(:lin)
    end
end

# ---------------------------------------------------------------------------

function _initialize_backend(::InspectDRBackend; kw...)
    @eval begin
        import InspectDR
        export InspectDR

        #Glyph used when plotting "Shape"s:
        const INSPECTDR_GLYPH_SHAPE = InspectDR.GlyphPolyline(
            2*InspectDR.GLYPH_SQUARE.x, InspectDR.GLYPH_SQUARE.y
        )

        type InspecDRPlotRef
            mplot::Union{Void, InspectDR.Multiplot}
            gui::Union{Void, InspectDR.GtkPlot}
        end

        _inspectdr_getmplot(::Any) = nothing
        _inspectdr_getmplot(r::InspecDRPlotRef) = r.mplot

        _inspectdr_getgui(::Any) = nothing
        _inspectdr_getgui(gplot::InspectDR.GtkPlot) = (gplot.destroyed? nothing: gplot)
        _inspectdr_getgui(r::InspecDRPlotRef) = _inspectdr_getgui(r.gui)
    end
end

# ---------------------------------------------------------------------------

# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{InspectDRBackend})
    mplot = _inspectdr_getmplot(plt.o)
    gplot = _inspectdr_getgui(plt.o)

    #:overwrite_figure: want to reuse current figure
    if plt[:overwrite_figure] && mplot != nothing
        mplot.subplots = [] #Reset
        if gplot != nothing #Ensure still references current plot
            gplot.src = mplot
        end
    else #want new one:
        mplot = InspectDR.Multiplot()
        gplot = nothing #Will be created later
    end

    #break link with old subplots
    for sp in plt.subplots
        sp.o = nothing
    end

    return InspecDRPlotRef(mplot, gplot)
end

# ---------------------------------------------------------------------------

# # this is called early in the pipeline, use it to make the plot current or something
# function _prepare_plot_object(plt::Plot{InspectDRBackend})
# end

# ---------------------------------------------------------------------------

# Set up the subplot within the backend object.
function _initialize_subplot(plt::Plot{InspectDRBackend}, sp::Subplot{InspectDRBackend})
    plot = sp.o

    #Don't do anything without a "subplot" object:  Will process later.
    if nothing == plot; return; end
    plot.data = []
    plot.markers = [] #Clear old markers
    plot.atext = [] #Clear old annotation
    plot.apline = [] #Clear old poly lines

    return plot
end

# ---------------------------------------------------------------------------

# Add one series to the underlying backend object.
# Called once per series
# NOTE: Seems to be called when user calls plot()... even if backend
#       plot, sp.o has not yet been constructed...
function _series_added(plt::Plot{InspectDRBackend}, series::Series)
    st = series[:seriestype]
    sp = series[:subplot]
    plot = sp.o

    #Don't do anything without a "subplot" object:  Will process later.
    if nothing == plot; return; end

    _vectorize(v) = isa(v, Vector)? v: collect(v) #InspectDR only supports vectors
    x = _vectorize(series[:x]); y = _vectorize(series[:y])

    # doesn't handle mismatched x/y - wrap data (pyplot behaviour):
    nx = length(x); ny = length(y)
    if nx < ny
        series[:x] = Float64[x[mod1(i,nx)] for i=1:ny]
    elseif ny > nx
        series[:y] = Float64[y[mod1(i,ny)] for i=1:nx]
    end

#= TODO: Eventually support
    series[:fillcolor] #I think this is fill under line
    zorder = series[:series_plotindex]

For st in :shape:
    zorder = series[:series_plotindex],
=#

    if st in (:shape,)
        nmax = 0
        for (i,rng) in enumerate(iter_segments(x, y))
            nmax = i
            if length(rng) > 1
                linewidth = series[:linewidth]
                linecolor = _inspectdr_mapcolor(cycle(series[:linecolor], i))
                fillcolor = _inspectdr_mapcolor(cycle(series[:fillcolor], i))
                line = InspectDR.line(
                    style=:solid, width=linewidth, color=linecolor
                )
                apline = InspectDR.PolylineAnnotation(
                    x[rng], y[rng], line=line, fillcolor=fillcolor
                )
                push!(plot.apline, apline)
            end
        end

        i = (nmax >= 2? div(nmax, 2): nmax) #Must pick one set of colors for legend
        if i > 1 #Add dummy waveform for legend entry:
            linewidth = series[:linewidth]
            linecolor = _inspectdr_mapcolor(cycle(series[:linecolor], i))
            fillcolor = _inspectdr_mapcolor(cycle(series[:fillcolor], i))
            wfrm = InspectDR.add(plot, Float64[], Float64[], id=series[:label])
            wfrm.line = InspectDR.line(
                style=:none, width=linewidth, #linewidth affects glyph
            )
            wfrm.glyph = InspectDR.glyph(
                shape = INSPECTDR_GLYPH_SHAPE, size = 8,
                color = linecolor, fillcolor = fillcolor
            )
        end
   elseif st in (:path, :scatter) #, :steppre, :steppost)
        #NOTE: In Plots.jl, :scatter plots have 0-linewidths (I think).
        linewidth = series[:linewidth]
        #More efficient & allows some support for markerstrokewidth:
        _style = (0==linewidth? :none: series[:linestyle])
        wfrm = InspectDR.add(plot, x, y, id=series[:label])
        wfrm.line = InspectDR.line(
            style = _style,
            width = series[:linewidth],
            color = series[:linecolor],
        )
        #InspectDR does not control markerstrokewidth independently.
        if :none == _style
            #Use this property only if no line is displayed:
            wfrm.line.width = series[:markerstrokewidth]
        end
        wfrm.glyph = InspectDR.glyph(
            shape = _inspectdr_mapglyph(series[:markershape]),
            size = _inspectdr_mapglyphsize(series[:markersize]),
            color = _inspectdr_mapcolor(series[:markerstrokecolor]),
            fillcolor = _inspectdr_mapcolor(series[:markercolor]),
        )
    end

    # this is all we need to add the series_annotations text
    anns = series[:series_annotations]
    for (xi,yi,str,fnt) in EachAnn(anns, x, y)
        _inspectdr_add_annotations(plot, xi, yi, PlotText(str, fnt))
    end
    return
end

# ---------------------------------------------------------------------------

# When series data is added/changed, this callback can do dynamic updates to the backend object.
# note: if the backend rebuilds the plot from scratch on display, then you might not do anything here.
function _series_updated(plt::Plot{InspectDRBackend}, series::Series)
    #Nothing to do
end

# ---------------------------------------------------------------------------

function _inspectdr_setupsubplot(sp::Subplot{InspectDRBackend})
    const gridon = InspectDR.grid(vmajor=true, hmajor=true)
    const gridoff = InspectDR.grid()
    const plot = sp.o

    xaxis = sp[:xaxis]; yaxis = sp[:yaxis]
        xscale = _inspectdr_getscale(xaxis[:scale])
        yscale = _inspectdr_getscale(yaxis[:scale])
        plot.axes = InspectDR.AxesRect(xscale, yscale)
        xmin, xmax  = axis_limits(xaxis)
        ymin, ymax  = axis_limits(yaxis)
        plot.ext = InspectDR.PExtents2D() #reset
        plot.ext_full = InspectDR.PExtents2D(xmin, xmax, ymin, ymax)
    a = plot.annotation
        a.title = sp[:title]
        a.xlabel = xaxis[:guide]; a.ylabel = yaxis[:guide]

    l = plot.layout
        l.framedata.fillcolor = _inspectdr_mapcolor(sp[:background_color_inside])
        l.framedata.line.color = _inspectdr_mapcolor(xaxis[:foreground_color_axis])
        l.fnttitle = InspectDR.Font(sp[:titlefont].family,
            _inspectdr_mapptsize(sp[:titlefont].pointsize),
            color = _inspectdr_mapcolor(sp[:foreground_color_title])
        )
        #Cannot independently control fonts of axes with InspectDR:
        l.fntaxlabel = InspectDR.Font(xaxis[:guidefont].family,
            _inspectdr_mapptsize(xaxis[:guidefont].pointsize),
            color = _inspectdr_mapcolor(xaxis[:foreground_color_guide])
        )
        l.fntticklabel = InspectDR.Font(xaxis[:tickfont].family,
            _inspectdr_mapptsize(xaxis[:tickfont].pointsize),
            color = _inspectdr_mapcolor(xaxis[:foreground_color_text])
        )
        #No independent control of grid???
        l.grid = sp[:grid]? gridon: gridoff
    leg = l.legend
        leg.enabled = (sp[:legend] != :none)
        #leg.width = 150 #TODO: compute???
        leg.font = InspectDR.Font(sp[:legendfont].family,
            _inspectdr_mapptsize(sp[:legendfont].pointsize),
            color = _inspectdr_mapcolor(sp[:foreground_color_legend])
        )
        leg.frame.fillcolor = _inspectdr_mapcolor(sp[:background_color_legend])
end

# called just before updating layout bounding boxes... in case you need to prep
# for the calcs
function _before_layout_calcs(plt::Plot{InspectDRBackend})
    const mplot = _inspectdr_getmplot(plt.o)
    if nothing == mplot; return; end

    resize!(mplot.subplots, length(plt.subplots))
    nsubplots = length(plt.subplots)
    for (i, sp) in enumerate(plt.subplots)
        if !isassigned(mplot.subplots, i)
            mplot.subplots[i] = InspectDR.Plot2D()
        end
        sp.o = mplot.subplots[i]
        _initialize_subplot(plt, sp)
        _inspectdr_setupsubplot(sp)

            sp.o.layout.frame.fillcolor =
                _inspectdr_mapcolor(plt[:background_color_outside])

        # add the annotations
        for ann in sp[:annotations]
            _inspectdr_add_annotations(mplot.subplots[i], ann...)
        end
    end

    #Do not yet support absolute plot positionning.
    #Just try to make things look more-or less ok:
    if nsubplots <= 1
        mplot.ncolumns = 1
    elseif nsubplots <= 4
        mplot.ncolumns = 2
    elseif nsubplots <= 6
        mplot.ncolumns = 3
    elseif nsubplots <= 12
        mplot.ncolumns = 4
    else
        mplot.ncolumns = 5
    end

    for series in plt.series_list
        _series_added(plt, series)
    end
    return
end

# ----------------------------------------------------------------

# Set the (left, top, right, bottom) minimum padding around the plot area
# to fit ticks, tick labels, guides, colorbars, etc.
function _update_min_padding!(sp::Subplot{InspectDRBackend})
    sp.minpad = (20mm, 5mm, 2mm, 10mm)
    #TODO: Add support for padding.
end

# ----------------------------------------------------------------

# Override this to update plot items (title, xlabel, etc), and add annotations (d[:annotations])
function _update_plot_object(plt::Plot{InspectDRBackend})
    mplot = _inspectdr_getmplot(plt.o)
    if nothing == mplot; return; end
    gplot = _inspectdr_getgui(plt.o)
    if nothing == gplot; return; end

    gplot.src = mplot #Ensure still references current plot
    InspectDR.refresh(gplot)
    return
end

# ----------------------------------------------------------------

const _inspectdr_mimeformats_dpi = Dict(
    "image/png"               => "png"
)
const _inspectdr_mimeformats_nodpi = Dict(
    "image/svg+xml"           => "svg",
    "application/eps"         => "eps",
    "image/eps"               => "eps",
#    "application/postscript"  => "ps", #TODO: support once Cairo supports PSSurface
    "application/pdf"         => "pdf"
)
_inspectdr_show(io::IO, mime::MIME, ::Void) =
    throw(ErrorException("Cannot show(::IO, ...) plot - not yet generated"))
_inspectdr_show(io::IO, mime::MIME, mplot) = show(io, mime, mplot)

for (mime, fmt) in _inspectdr_mimeformats_dpi
    @eval function _show(io::IO, mime::MIME{Symbol($mime)}, plt::Plot{InspectDRBackend})
        dpi = plt[:dpi]#TODO: support
        _inspectdr_show(io, mime, _inspectdr_getmplot(plt.o))
    end
end
for (mime, fmt) in _inspectdr_mimeformats_nodpi
    @eval function _show(io::IO, mime::MIME{Symbol($mime)}, plt::Plot{InspectDRBackend})
        _inspectdr_show(io, mime, _inspectdr_getmplot(plt.o))
    end
end
_show(io::IO, mime::MIME"text/plain", plt::Plot{InspectDRBackend}) = nothing #Don't show

# ----------------------------------------------------------------

# Display/show the plot (open a GUI window, or browser page, for example).
function _display(plt::Plot{InspectDRBackend})
    mplot = _inspectdr_getmplot(plt.o)
    if nothing == mplot; return; end
    gplot = _inspectdr_getgui(plt.o)

    if nothing == gplot && true == plt[:show]
        gplot = display(InspectDR.GtkDisplay(), mplot)
    else
        #redundant... Plots.jl will call _update_plot_object:
        #InspectDR.refresh(gplot)
    end
    plt.o = InspecDRPlotRef(mplot, gplot)
    return gplot
end
