package cjcj.printUtils

public class PrintUtils {
    public static func indent(val: Int64): String {
        StringBuilder(r" ", val).toString()
    }
}