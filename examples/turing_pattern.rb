#!/usr/bin/env ruby

# https://en.wikipedia.org/wiki/Turing_pattern
#
# > The Turing pattern is a concept introduced by English mathematician Alan Turing
# in a 1952 paper titled "The Chemical Basis of Morphogenesis" which describes
# how patterns in nature, such as stripes and spots, can arise naturally and
# autonomously from a homogeneous, uniform state.
#
# > In his classic paper, Turing examined the behaviour of a system in which two
# diffusible substances interact with each other, and found that such a system
# is able to generate a spatially periodic pattern even from a random or almost
# uniform initial condition. Turing hypothesized that the resulting wavelike
# patterns are the chemical basis of morphogenesis.

# Studies of Turing pattern formation in zebrafish skin (2021)
# https://doi.org/10.1098/rsta.2020.0274
#
# > An unexpected discovery was made regarding the mechanism responsible for
# cell–cell interactions. When isolated melanophores and xanthophores were
# co-cultured in vitro, the cells were found to repel each other, but the signal
# was transmitted by short protrusion extending from the xanthophores. Regarding
# distant interactions, Hamada et al. found that long cell protrusions extending
# from the melanophores were involved (figure 3a–c). Interestingly, neither
# short- nor long-range interactions are mediated by ‘diffusion’. Therefore,
# strictly speaking, pattern formation does not occur by a reaction–diffusion
# system. However, mathematically, it can be considered as a homologous
# phenomenon, because the protrusions with two different lengths mimic the role
# of two different molecules with different diffusion coefficients in a
# reaction–diffusion system.
#
# > What established the pattern is not the shading of the chemicals, but the
# distribution of cells that behave autonomously. Another major difference is
# that long-distance signalling is conveyed directly by cell protrusions rather
# than by molecular diffusion.

# Perhaps Turing and his contemporaries were not right about the precise
# mechanism of pattern formation. It may be that the propagation of waves of
# cell signaling through direct contact, rather than the diffusion of morphogens,
# forms the pattern of the organism.
# However, the patterns generated by the diffusion reaction system are very
# impressive...

WAIT_TIME = 200 # Increase this number if you cannot redraw in time.
NUM_STEPS = 50  # Number of steps before being redrawn.

require 'libui'
# A matrix calculation library for Ruby like NumPy.
require 'numo/narray'

# generate png image from narray(faster)
# require 'magro'
require 'chunky_png'

module GrayScott
  # shorthand
  SFloat = Numo::SFloat
  UInt8  = Numo::UInt8

  class SFloat
    alias _ inplace
  end

  module Utils
    # To avoid mistakes
    A = (1..-1).freeze
    B = (0..-2).freeze
    T = true

    def self.laplacian2d(uv, dx)
      l_uv = uv.new_zeros
      l_uv[A, T]._ + uv[B, T]
      l_uv[T, A]._ + uv[T, B]

      l_uv[0, T]._ + uv[-1, T]
      l_uv[T, 0]._ + uv[T, -1]

      l_uv[B, T]._ + uv[A, T]
      l_uv[T, B]._ + uv[T, A]

      l_uv[-1, T]._ + uv[0, T]
      l_uv[T, -1]._ + uv[T, 0]

      l_uv._ - (uv * 4)
      l_uv._ / (dx * dx)
      l_uv
    end
  end

  # Gray-Scott model
  class Model
    Dx = 0.01

    # Delta t is the change in time for each iteration
    Dt = 1

    # diffusion rate for U
    Du = 2e-5

    # diffusion rate for V
    Dv = 1e-5

    attr_accessor :f, :k, :u, :v
    attr_reader :width, :height

    def initialize(width: 256, height: 256)
      @width  = width
      @height = height

      # Feed rate
      @f = 0.04

      # Kill rate
      @k = 0.06

      # concentration of U
      @u = SFloat.ones height, width

      # concentration of V
      @v = SFloat.zeros height, width
    end

    def clear
      u.fill 1.0
      v.fill 0.0
    end

    def step
      l_u = Utils.laplacian2d u, Dx
      l_v = Utils.laplacian2d v, Dx

      uvv = u * v * v
      dudt = Du * l_u - uvv + f * (1.0 - u)
      dvdt = Dv * l_v + uvv - (f + k) * v
      u._ + (Dt * dudt)
      v._ + (Dt * dvdt)

      # clip is better.
      @u[@u.lt 0.00001] = 0.00001
      @u[@u.gt 1] = 1
      @v[@v.lt 0.00001] = 0.00001
      @v[@v.gt 1] = 1
    end
  end

  module Color
    module_function

    def colorize(ar, color_type)
      case color_type
      when 'colorful'
        hsv2rgb(ar)
      when 'reverse-colorful'
        hsv2rgb(1.0 - ar)
      when 'red'
        red(ar)
      when 'green'
        green(ar)
      when 'blue'
        blue(ar)
      when 'reverse-red'
        reverse_red(ar)
      when 'reverse-green'
        reverse_green(ar)
      when 'reverse-blue'
        reverse_blue(ar)
      when 'grayscale'
        grayscale(ar)
      end
    end

    # speed
    def uInt8_dstack(ar)
      x = UInt8.zeros(*ar[0].shape, 3)
      x[true, true, 0] = ar[0]
      x[true, true, 1] = ar[1]
      x[true, true, 2] = ar[2]
      x
    end

    def hsv2rgb(h)
      i = UInt8.cast(h * 6)
      f = (h * 6.0) - i
      p = UInt8.zeros(*h.shape)
      v = UInt8.new(*h.shape).fill 255
      q = (1.0 - f) * 256
      t = f * 256
      rgb = UInt8.zeros(*h.shape, 3)
      t = UInt8.cast(t)
      i = uInt8_dstack([i, i, i])
      rgb[i.eq 0] = uInt8_dstack([v, t, p])[i.eq 0]
      rgb[i.eq 1] = uInt8_dstack([q, v, p])[i.eq 1]
      rgb[i.eq 2] = uInt8_dstack([p, v, t])[i.eq 2]
      rgb[i.eq 3] = uInt8_dstack([p, q, v])[i.eq 3]
      rgb[i.eq 4] = uInt8_dstack([t, p, v])[i.eq 4]
      rgb[i.eq 5] = uInt8_dstack([v, p, q])[i.eq 5]
      rgb
    end

    def red(ar)
      uint8_zeros_256(0, ar)
    end

    def green(ar)
      uint8_zeros_256(1, ar)
    end

    def blue(ar)
      uint8_zeros_256(2, ar)
    end

    def reverse_red(ar)
      uint8_zeros_256(0, (1.0 - ar))
    end

    def reverse_green(ar)
      uint8_zeros_256(1, (1.0 - ar))
    end

    def reverse_blue(ar)
      uint8_zeros_256(2, (1.0 - ar))
    end

    def grayscale(ar)
      d = ar * 255
      uInt8_dstack([d, d, d])
    end

    def uint8_zeros_256(ch, ar)
      d = UInt8.zeros(*ar.shape, 3)
      d[true, true, ch] = UInt8.cast(ar * 256)
      d
    end
  end
end

UI = LibUI
UI.init

width        = 100
height       = 100
ratio        = 2
pix_size     = 4
pointer_size = 5
model_width  = width * ratio
model_height = height * ratio

@model = GrayScott::Model.new(width: model_width, height: model_height)
@model.clear
@color_type = 'colorful'
@uv = 'v'
@running = false

# menu File

menu_file = UI.new_menu('File')
menu_file_new = UI.menu_append_item(menu_file, 'New')
UI.menu_item_on_clicked(menu_file_new) do
  @model.clear
  UI.area_queue_redraw_all(@area)
end

# menu File Open

menu_file_open = UI.menu_append_item(menu_file, 'Open Model')
UI.menu_item_on_clicked(menu_file_open) do
  pt = UI.open_file(@main_window)
  unless pt.null?
    file_path = pt.to_s
    begin
      model = Marshal.load(File.binread(file_path))
    rescue StandardError => e
      UI.msg_box_error(
        @main_window, '⚠️ Error',
        "Failed to open file.\n" \
        "#{file_path}\n" \
        "#{e.message}"
      )
      next
    end
    if model.width == @model.width &&
       model.height == @model.height
      @model = model
      UI.area_queue_redraw_all(@area)
    else
      UI.msg_box_error(
        @main_window, '⚠️ Error',
        "File shape is different.\n" \
        "file: width #{model.width} height #{model.height}\n" \
        "model: width #{@model.width} height #{@model.height}"
      )
    end
  end
end

@save_file_path = nil

save_model_as_proc = proc do
  pt = UI.save_file(@main_window)
  unless pt.null?
    @save_file_path = pt.to_s
    Marshal.dump(@model, File.open(@save_file_path, 'wb'))
  end
end

# menu File Save

menu_file_save = UI.menu_append_item(menu_file, 'Save Model')
UI.menu_item_on_clicked(menu_file_save) do
  if @save_file_path
    Marshal.dump(@model, File.open(@save_file_path, 'wb'))
  else
    save_model_as_proc.call
  end
end

# menu File Save As

menu_file_save_as = UI.menu_append_item(menu_file, 'Save Model As')
UI.menu_item_on_clicked(menu_file_save_as, save_model_as_proc)

# menu File Quit

quit_proc = proc do
  @running = false
  UI.control_destroy(@main_window)
  UI.quit
  0
end

menu_file_quit = UI.menu_append_item(menu_file, 'Quit')
UI.menu_item_on_clicked(menu_file_quit, quit_proc)

# menu Help

menu_help = UI.new_menu('Help')
menu_help_about = UI.menu_append_item(menu_help, 'About')
UI.menu_item_on_clicked(menu_help_about) do
  UI.msg_box(
    @main_window,
    '🦓 Turing Pattern 🐠',
    <<~HELP_MESSAGE
      How to use

      (1) Click on the red area several times. Blue dots will show up.
      (2) Press the "▶ START" button.
      (3) Try out different parameters.

      Written in Ruby
      https://github.com/kojix2/LibUI
    HELP_MESSAGE
  )
end

# area

area_handler = UI::FFI::AreaHandler.malloc
area_handler.to_ptr.free = Fiddle::RUBY_FREE
@area = UI.new_area(area_handler)
brush = UI::FFI::DrawBrush.malloc
brush.to_ptr.free = Fiddle::RUBY_FREE

handler_draw_event = Fiddle::Closure::BlockCaller.new(0, [1, 1, 1]) do |_, _, area_draw_params|
  area_draw_params = UI::FFI::AreaDrawParams.new(area_draw_params)
  rgb = (GrayScott::Color.colorize(@model.public_send(@uv.to_sym), @color_type)
                         .cast_to(Numo::SFloat)
                         .inplace / 255.0)
        .reshape!(height, ratio, width, ratio, 3).sum(1, 3) # Resize
        .inplace / (ratio**2)
  # 200 x 200 => 100 x 100 because LibUI is slow...
  height.times do |y|
    width.times do |x|
      path = UI.draw_new_path(UI::DrawFillModeWinding)
      UI.draw_path_add_rectangle(path,
                                 pix_size * (x + 1), pix_size * (y + 1),
                                 pix_size, pix_size)
      UI.draw_path_end(path)
      brush.Type = 0
      brush.R = rgb[y, x, 0]
      brush.G = rgb[y, x, 1]
      brush.B = rgb[y, x, 2]
      brush.A = 1.0
      UI.draw_fill(area_draw_params.Context, path, brush.to_ptr)
      UI.draw_free_path(path)
    end
  end
end

do_nothing = Fiddle::Closure::BlockCaller.new(0, [0]) {}
key_event  = Fiddle::Closure::BlockCaller.new(1, [0]) { 0 }

handler_mouse_event = Fiddle::Closure::BlockCaller.new(0, [1, 1, 1]) do |_, _, e|
  e = UI::FFI::AreaMouseEvent.new(e)
  if e.Down == 1
    x = e.X * (ratio / pix_size.to_f)
    y = e.Y * (ratio / pix_size.to_f)
    next if x >= model_width + pointer_size ||
            y >= model_height + pointer_size

    yrange = ([(y - pointer_size), 0].max)..([y, (model_height - 1)].min)
    xrange = ([(x - pointer_size), 0].max)..([x, (model_width - 1)].min)
    @model.u[yrange, xrange] = 0.5
    @model.v[yrange, xrange] = 0.5
    UI.area_queue_redraw_all(@area)
  end
end

area_handler.Draw         = handler_draw_event
area_handler.MouseEvent   = handler_mouse_event
area_handler.MouseCrossed = do_nothing
area_handler.DragBroken   = do_nothing
area_handler.KeyEvent     = key_event

# slide_feed

label_f = UI.new_label('f')
slider_feed = UI.new_slider(0, 100)
UI.slider_set_value(slider_feed, @model.f * 1000)
UI.slider_on_changed(slider_feed) do |ptr|
  @model.f = UI.slider_value(ptr) / 1000.0
end

# slider_kill

label_k = UI.new_label('k')
slider_kill = UI.new_slider(0, 100)
UI.slider_set_value(slider_kill, @model.k * 1000)
UI.slider_on_changed(slider_kill) do |ptr|
  @model.k = UI.slider_value(ptr) / 1000.0
end

# combobox preset

# The presets are taken from the following implementations:
# https://github.com/pmneila/jsexp

presets = [
  {
    name: 'Default',
    feed: 0.037,
    kill: 0.06
  },  {
    name: 'Solitons',
    feed: 0.03,
    kill: 0.062
  },  {
    name: 'Pulsating Solitons',
    feed: 0.025,
    kill: 0.06
  },  {
    name: 'Worms',
    feed: 0.078,
    kill: 0.061
  },  {
    name: 'Mazes',
    feed: 0.029,
    kill: 0.057
  },  {
    name: 'Holes',
    feed: 0.039,
    kill: 0.058
  },  {
    name: 'Chaos',
    feed: 0.026,
    kill: 0.051
  },  {
    name: 'Chaos and holes',
    feed: 0.034,
    kill: 0.056
  },  {
    name: 'Moving spots',
    feed: 0.014,
    kill: 0.054
  },  {
    name: 'Spots and loops',
    feed: 0.018,
    kill: 0.051
  },  {
    name: 'Waves',
    feed: 0.014,
    kill: 0.045
  },  {
    name: 'The U-Skate World',
    feed: 0.062,
    kill: 0.06093
  }
]

cbox_presets = UI.new_combobox
presets.each do |preset|
  UI.combobox_append(cbox_presets, preset[:name])
end
UI.combobox_set_selected(cbox_presets, 0)
UI.combobox_on_selected(cbox_presets) do |ptr|
  preset = presets[UI.combobox_selected(ptr)]
  @model.f = preset[:feed]
  @model.k = preset[:kill]
  UI.slider_set_value(slider_feed, preset[:feed] * 1000)
  UI.slider_set_value(slider_kill, preset[:kill] * 1000)
end

# combobox u/v

uv = %w[u v]
cbox_uv = UI.new_combobox
uv.each do |s|
  UI.combobox_append(cbox_uv, s)
end
UI.combobox_set_selected(cbox_uv, 1)
UI.combobox_on_selected(cbox_uv) do |ptr|
  @uv = uv[UI.combobox_selected(ptr)]
  UI.area_queue_redraw_all(@area) unless @running
end

# combobox color

color_type_list = %w[
  colorful
  reverse-colorful
  red
  green
  blue
  reverse-red
  reverse-green
  reverse-blue
  grayscale
]

cbox_color = UI.new_combobox
color_type_list.each do |s|
  UI.combobox_append(cbox_color, s)
end
UI.combobox_set_selected(cbox_color, 0)
UI.combobox_on_selected(cbox_color) do |ptr|
  @color_type = color_type_list[UI.combobox_selected(ptr)]
  UI.area_queue_redraw_all(@area) unless @running
end

# button start/stop

button_start = UI.new_button('▶️ START')
UI.button_on_clicked(button_start) do
  @running = !@running
  UI.button_set_text(button_start,
                     @running ? '🛑 STOP' : '▶️ START')
end

# button capture

button_capture = UI.new_button('📷')
UI.button_on_clicked(button_capture) do
  image = GrayScott::Color.colorize(@model.public_send(@uv.to_sym), @color_type)

  pt = UI.save_file(@main_window)
  unless pt.null?
    file_path = pt.to_s
    if defined?(Magro::IO)
      Magro::IO.imsave(file_path, image)
    else
      img = ChunkyPNG::Image.from_rgb_stream(model_width, model_height, image.to_string)
      img.save(file_path)
    end
  end
end

# hbox

hbox1 = UI.new_horizontal_box
UI.box_set_padded(hbox1, 1)
UI.box_append(hbox1, cbox_presets, 0)
UI.box_append(hbox1, label_f, 0)
UI.box_append(hbox1, slider_feed, 1)
UI.box_append(hbox1, label_k, 0)
UI.box_append(hbox1, slider_kill, 1)

hbox2 = UI.new_horizontal_box
UI.box_set_padded(hbox2, 1)
UI.box_append(hbox2, cbox_uv, 0)
UI.box_append(hbox2, cbox_color, 0)
UI.box_append(hbox2, button_start, 1)
UI.box_append(hbox2, button_capture, 0)

# vbox

vbox = UI.new_vertical_box
UI.box_set_padded(vbox, 1)
UI.box_append(vbox, hbox1, 0)
UI.box_append(vbox, hbox2, 0)
UI.box_append(vbox, @area, 1)

# main window

@main_window = UI.new_window('Turing Pattern', 440, 560, 1)
UI.window_set_margined(@main_window, 1)
UI.window_set_child(@main_window, vbox)

UI.window_on_closing(@main_window, quit_proc)
UI.control_show(@main_window)

# queue

UI.queue_main do
  UI.timer(WAIT_TIME) do
    next 1 unless @running # do nothing

    NUM_STEPS.times do
      @model.step
    end
    UI.area_queue_redraw_all(@area)
    1 # continue
  end
end

UI.main
UI.quit
