package cjcj.prettyPrinter

public class PrettyPrinter {
    private static var indentation: Int64 = 0
    private static let builder: StringBuilder = StringBuilder()

    public static func indent(): Unit {
        indentation++
    }

    public static func unindent(): Unit {
        indentation--
    }

    public static func append(val: String): Unit {
        val.runes().forEach({
            r => builder.append(r)
            if (r == r"\n") {
                builder.append(StringBuilder(r' ', 4 * indentation))
            }
        })
    }

    public static func toString(): String {
        builder.toString()
    }
}