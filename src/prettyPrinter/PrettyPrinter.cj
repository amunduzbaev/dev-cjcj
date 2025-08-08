package cjcj.prettyPrinter

public class PrettyPrinter {
    private var indentation: Int64 = 0
    private let builder: StringBuilder = StringBuilder()

    public func indent(): Unit {
        indentation++
    }

    public func unindent(): Unit {
        indentation--
    }

    public func append(val: String): Unit {
        val.runes().forEach({
            r => builder.append(r)
            if (r == r"\n") {
                builder.append(StringBuilder(r' ', 4 * indentation))
            }
        })
    }

    public func toString(): String {
        builder.toString()
    }
}