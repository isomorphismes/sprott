module sprott_raster;

import std.exception : enforce;
import std.math : abs, cos, sin;
import std.stdio : File;

import sprott_core;

final class Raster
{
    int width;
    int height;
    private ubyte[] pixels;
    Window window;

    this(int width, int height)
    {
        enforce(width > 0 && height > 0);
        this.width = width;
        this.height = height;
        pixels = new ubyte[cast(size_t)(width * height)];
        clear(0);
    }

    void clear(ubyte color)
    {
        pixels[] = color;
    }

    void setWindow(Window w)
    {
        window = w;
    }

    private bool map(double x, double y, out int px, out int py) const
    {
        if (!window.ready)
            return false;
        const double rx = safeRange(window.xl, window.xh);
        const double ry = safeRange(window.yl, window.rasterYh);
        const double fx = (x - window.xl) / rx;
        const double fy = (window.rasterYh - y) / ry;
        px = roundPixel(fx * (width - 1));
        py = roundPixel(fy * (height - 1));
        return px >= 0 && px < width && py >= 0 && py < height;
    }

    void pset(double x, double y, ubyte color)
    {
        int px;
        int py;
        if (map(x, y, px, py))
            pixels[cast(size_t)(py * width + px)] = color;
    }

    int point(double x, double y) const
    {
        int px;
        int py;
        if (!map(x, y, px, py))
            return -1;
        return pixels[cast(size_t)(py * width + px)];
    }

    private void setPixel(int x, int y, ubyte color)
    {
        if (x >= 0 && x < width && y >= 0 && y < height)
            pixels[cast(size_t)(y * width + x)] = color;
    }

    void line(double x0, double y0, double x1, double y1, ubyte color)
    {
        int ax;
        int ay;
        int bx;
        int by;
        if (!map(x0, y0, ax, ay) || !map(x1, y1, bx, by))
            return;

        int dx = abs(bx - ax);
        int sx = ax < bx ? 1 : -1;
        int dy = -abs(by - ay);
        int sy = ay < by ? 1 : -1;
        int err = dx + dy;
        int x = ax;
        int y = ay;
        while (true)
        {
            setPixel(x, y, color);
            if (x == bx && y == by)
                break;
            const int e2 = 2 * err;
            if (e2 >= dy)
            {
                err += dy;
                x += sx;
            }
            if (e2 <= dx)
            {
                err += dx;
                y += sy;
            }
        }
    }

    void rectangle(double xl, double yl, double xh, double yh, ubyte color)
    {
        line(xl, yl, xh, yl, color);
        line(xh, yl, xh, yh, color);
        line(xh, yh, xl, yh, color);
        line(xl, yh, xl, yl, color);
    }

    void circle(double cx, double cy, double radius, ubyte color)
    {
        enum int segments = 720;
        double px = cx + radius;
        double py = cy;
        foreach (i; 1 .. segments + 1)
        {
            const double a = TWO_PI * i / segments;
            const double nx = cx + radius * cos(a);
            const double ny = cy + radius * sin(a);
            line(px, py, nx, ny, color);
            px = nx;
            py = ny;
        }
    }

    void fillWindow(ubyte color)
    {
        clear(color);
    }

    private static immutable ubyte[3][16] ega = [
        [0, 0, 0], [0, 0, 170], [0, 170, 0], [0, 170, 170],
        [170, 0, 0], [170, 0, 170], [170, 85, 0], [170, 170, 170],
        [85, 85, 85], [85, 85, 255], [85, 255, 85], [85, 255, 255],
        [255, 85, 85], [255, 85, 255], [255, 255, 85], [255, 255, 255]
    ];

    void writePpm(string path) const
    {
        auto file = File(path, "wb");
        file.writef("P6\n%d %d\n255\n", width, height);
        auto rgb = new ubyte[cast(size_t)(width * height * 3)];
        foreach (i, color; pixels)
        {
            const auto c = ega[color & 15];
            rgb[3 * i] = c[0];
            rgb[3 * i + 1] = c[1];
            rgb[3 * i + 2] = c[2];
        }
        file.rawWrite(rgb);
    }
}
