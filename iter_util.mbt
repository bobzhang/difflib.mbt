///|
/// Returns an iterator that calls `make` only when its first element is
/// requested, like the body of a Python generator function.
fn[T] deferred(make : () -> Iter[T]) -> Iter[T] {
  let mut inner : Iter[T]? = None
  Iter::new(() => {
    let it = match inner {
      Some(it) => it
      None => {
        let it = make()
        inner = Some(it)
        it
      }
    }
    it.next()
  })
}
