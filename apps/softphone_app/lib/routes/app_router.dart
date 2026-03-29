enum AppSection {
  calls('/'),
  accounts('/accounts'),
  contacts('/contacts'),
  history('/history'),
  settings('/settings'),
  diagnostics('/diagnostics');

  const AppSection(this.path);
  final String path;
}
