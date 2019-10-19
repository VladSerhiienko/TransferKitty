package vserhiienko.transferkitty;

public interface TKFunc<T, R> {
    R apply(T t);
}
