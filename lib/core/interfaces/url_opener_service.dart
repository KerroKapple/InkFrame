// UrlOpenerService：在系统默认浏览器打开外部链接的抽象契约（UPD-1）。
//
// 契约：仅接受 http/https——其他 scheme 属调用方编程错误,抛 ArgumentError;
// 系统层打开失败抛 LocalIOError。widget 永不直接依赖具体实现。
abstract class UrlOpenerService {
  Future<void> openExternal(Uri url);
}
