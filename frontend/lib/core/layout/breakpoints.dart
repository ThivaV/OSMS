/// Phone < 600 px, tablet 600–1024 px, desktop > 1024 px.
enum WindowSize {
  phone,
  tablet,
  desktop;

  static const double tabletMin = 600;
  static const double desktopMin = 1024;

  static WindowSize fromWidth(double width) {
    if (width < tabletMin) return phone;
    if (width <= desktopMin) return tablet;
    return desktop;
  }
}
