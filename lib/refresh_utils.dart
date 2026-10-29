Future<void> settle(Future<dynamic> task) async {
  try {
    await task;
  } catch (_) {}
}
