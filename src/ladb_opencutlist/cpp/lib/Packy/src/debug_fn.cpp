void trapezoid_set_to_svg(
        TrapezoidSet& trapezoid_set,
        std::ostream& os,
        LengthDbl inflate_value = 0.0,
        double zoom = 10)
{

  LengthDbl inflate_offset = inflate_value * 20;

  LengthDbl vb_width = ((trapezoid_set.x_max - trapezoid_set.x_min) + inflate_offset * 2) * zoom;
  LengthDbl vb_height = ((trapezoid_set.y_max - trapezoid_set.y_min) + inflate_offset * 2) * zoom;
  LengthDbl vb_x = (trapezoid_set.x_min - inflate_offset) * zoom;
  LengthDbl vb_y = -(trapezoid_set.y_min - inflate_offset) * zoom - vb_height;

  os << "<svg viewBox=\"" << vb_x << " " << vb_y << " " << vb_width << " " << vb_height << "\" version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\">";
  os << "<style>path { fill: #eee; stroke: black; stroke-width: 0.1; } .inflated path { fill: red; }</style>";

  if (inflate_value > 0.0) {

    os << "<g class=\"inflated\">";
    for (auto &trapezoids: trapezoid_set.shapes) {

      os << "<g>";

      for (auto &trapezoid: trapezoids) {
        auto inflated_trapezoid = trapezoid.inflate(inflate_value);
        os << "<path d=\""
           << "M" << inflated_trapezoid.x_bottom_left() * zoom << "," << -inflated_trapezoid.y_bottom() * zoom
           << "L" << inflated_trapezoid.x_bottom_right() * zoom << "," << -inflated_trapezoid.y_bottom() * zoom
           << "L" << inflated_trapezoid.x_top_right() * zoom << "," << -inflated_trapezoid.y_top() * zoom
           << "L" << inflated_trapezoid.x_top_left() * zoom << "," << -inflated_trapezoid.y_top() * zoom
           << "Z\"/>";
      }

      os << "</g>";

    }
    os << "</g>";

  }

  os << "<g>";
  for (auto& trapezoids : trapezoid_set.shapes) {

    os << "<g>";

    for (auto& trapezoid : trapezoids) {
      os << "<path d=\""
         << "M" << trapezoid.x_bottom_left() * zoom << "," << -trapezoid.y_bottom() * zoom
         << "L" << trapezoid.x_bottom_right() * zoom << "," << -trapezoid.y_bottom() * zoom
         << "L" << trapezoid.x_top_right() * zoom << "," << -trapezoid.y_top() * zoom
         << "L" << trapezoid.x_top_left() * zoom << "," << -trapezoid.y_top() * zoom
         << "Z\"/>";
    }

    os << "</g>";

  }
  os << "</g>";

  os << "</svg>" << std::endl;

}
