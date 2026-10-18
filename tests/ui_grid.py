"""Render Neovim RGB grid events, used only by the optional screenshot test."""


class UIGrid:
    def __init__(self, nvim, width, height):
        self.nvim, self.width, self.height = nvim, width, height
        self.grid = [[(' ', 0) for _ in range(self.width)] for _ in range(self.height)]
        self.highlights = {0: {}}
        self.defaults = {'foreground': 0xc8d3f5, 'background': 0x222436}

    def notification(self, name, args):

        if name == 'capture_ready':
            self.nvim.stop_loop()
        if name != 'redraw':
            return
        for event in args:
            label = event[0]
            for values in event[1:]:
                if label == 'default_colors_set':
                    self.defaults.update(foreground=values[0], background=values[1])
                elif label == 'hl_attr_define':
                    self.highlights[values[0]] = values[1]
                elif label == 'grid_resize' and values[0] == 1:
                    _, self.width, self.height = values
                    self.grid = [[(' ', 0) for _ in range(self.width)] for _ in range(self.height)]
                elif label == 'grid_clear' and values[0] == 1:
                    self.grid = [[(' ', 0) for _ in range(self.width)] for _ in range(self.height)]
                elif label == 'grid_line' and values[0] == 1:
                    _, row, col, cells, *_ = values
                    hl = 0
                    for cell in cells:
                        if len(cell) > 1: hl = cell[1]
                        repeat = cell[2] if len(cell) > 2 else 1
                        for _ in range(repeat):
                            if row < self.height and col < self.width: self.grid[row][col] = (cell[0], hl)
                            col += 1
                elif label == 'grid_scroll' and values[0] == 1:
                    _, top, bottom, left, right, rows, cols = values
                    old = [r[:] for r in self.grid]
                    for row in range(top, bottom):
                        for col in range(left, right):
                            source_row, source_col = row + rows, col + cols
                            self.grid[row][col] = old[source_row][source_col] if top <= source_row < bottom and left <= source_col < right else (' ', 0)

    def drain(self, milliseconds=2000):
        self.nvim.exec_lua('local channel, ms = ...; vim.defer_fn(function() vim.rpcnotify(channel, "capture_ready") end, ms)', self.nvim.channel_id, milliseconds)
        self.nvim.run_loop(None, self.notification)

    def save(self, path, font_path):
        from PIL import Image, ImageDraw, ImageFont
        self.nvim.command("redraw!")
        self.drain(200)
        font = ImageFont.truetype(str(font_path), 15)
        bold = ImageFont.truetype(str(font_path), 15)
        cw, ch, pad = 9, 22, 16
        canvas = Image.new('RGB', (self.width*cw + pad*2, self.height*ch + pad*2), '#222436')
        draw = ImageDraw.Draw(canvas)
        for row in range(self.height):
            for col in range(self.width):
                text, hl = self.grid[row][col]
                attrs = self.highlights.get(hl, {})
                fg, bg = attrs.get('foreground', self.defaults['foreground']), attrs.get('background', self.defaults['background'])
                if attrs.get('reverse'): fg, bg = bg, fg
                x, y = pad+col*cw, pad+row*ch
                draw.rectangle((x,y,x+cw-1,y+ch-1), fill=f'#{bg:06x}')
                if text and text != ' ':
                    draw.text((x,y+2), text, font=bold if attrs.get('bold') else font, fill=f'#{fg:06x}')
        canvas.save(path)
