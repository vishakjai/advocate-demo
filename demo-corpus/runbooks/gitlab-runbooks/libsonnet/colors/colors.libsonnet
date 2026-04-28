local rgba(red, green, blue, alpha) =
  {
    red: red,
    green: green,
    blue: blue,
    alpha: alpha,
    toRGBA():: 'rgba(%(red)d,%(green)d,%(blue)d,%(alpha).2f)' % self,
    toHex():: if alpha == 1 then
      '#%(red)02x%(green)02x%(blue)02x' % self
    else
      '#%(red)02x%(green)02x%(blue)02x%(alpha_hex)02x' % (self + { alpha_hex: std.floor(alpha * 255) }),
    toString()::
      if alpha == 1 then
        self.toHex()
      else
        self.toRGBA(),
  };

local hex(string) =
  local s = std.lstripChars(string, '#');
  local hasAlpha = std.length(s) == 8;
  local red = std.parseHex(std.substr(s, 0, 2));
  local green = std.parseHex(std.substr(s, 2, 2));
  local blue = std.parseHex(std.substr(s, 4, 2));
  local alpha = if hasAlpha then std.parseHex(std.substr(s, 6, 2)) / 255 else 1;
  rgba(red, green, blue, alpha);

// Returns an array of colors in a linear gradient
local linearGradient(start, end, steps) =

  if steps == 1 then
    [start]
  else if steps == 2 then
    [start, end]
  else
    local deltaRed = (end.red - start.red) / (steps - 1);
    local deltaGreen = (end.green - start.green) / (steps - 1);
    local deltaBlue = (end.blue - start.blue) / (steps - 1);
    local deltaAlpha = (end.alpha - start.alpha) / (steps - 1);

    (
      [
        rgba(
          red=start.red + i * deltaRed,
          green=start.green + i * deltaGreen,
          blue=start.blue + i * deltaBlue,
          alpha=start.alpha + i * deltaAlpha,
        )
        for i in std.range(0, steps - 2)
      ] +
      [end]
    );

{
  hex(string):: hex(string),
  rgba(red, green, blue, alpha):: rgba(red, green, blue, alpha),
  linearGradient:: linearGradient,

  // Colors taken from Grafana color picker palettes
  GREEN:: hex('#73BF69'),
  BLUE:: hex('#5794F280'),
  ORANGE:: hex('#FF9830'),
  RED:: hex('#F2495C'),
  YELLOW:: hex('#FADE2A'),
  PURPLE:: hex('#B877D9'),
}
