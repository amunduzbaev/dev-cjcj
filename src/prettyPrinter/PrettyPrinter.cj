package cjcj.prettyPrinter

public class PrettyPrinter {
    public static func indent(val: Int64): String {
        StringBuilder(r" ", val).toString()
    }
}