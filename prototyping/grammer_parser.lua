

local lpeg = require"lpeg"

local l, lo, P, V, C, Ct, Cf, Cg, Cc, Cs, Cp, _, __, x, ux, ix, xV, xP, Ci, chain
do -- lpeg utilities
    l, lo = lpeg, lpeg.locale()
    P, V, C, Ct, Cf, Cg, Cc, Cs, Cp = l.P, l.V, l.C, l.Ct, l.Cf, l.Cg, l.Cc, l.Cs, l.Cp
    _ = (V"comment"+V"multiline_comment"+lo.space)^0
    __ = (V"comment"+V"multiline_comment"+lo.space)^1
    
    local function parse_error(pos, err, ...)
        error{pos = pos, message = string.format(err, ...)}
    end
    local function Cmt_err(str, pos, c, err, ...) -- this is so messy
        parse_error(pos,
            string.gsub(err, "%%([%d%%])", function(s)
                if s == "%" then return "%" end
                return string.format("%q", tostring(c[s]))
            end),
            ...
        )
    end
    x = function(patt, err, ...) -- expect
        local arg = {...}
        return patt+l.Cmt("", function(str, pos, ...) Cmt_err(str, pos, {...}, err, unpack(arg)) end)
    end
    ux = function(patt, err, ...) -- unexpect
        local arg = {...}
        return l.Cmt(patt, function(str, pos, ...) Cmt_err(str, pos, {...}, err, unpack(arg)) end) + ""
    end
    ix = function(patt, err, ...) -- error if
        local arg = {...}
        return l.Cmt(patt, function(str, pos, ...) Cmt_err(str, pos, {...}, err, unpack(arg)) end)
    end
    xV = function(name, oname, ...)
        return oname and x(V(name), oname, ...) or x(V(name), "expected %s", string.gsub(name, "_", " "))
    end
    xP = function(str, ostr, ...)
        return ostr and x(P(str), ostr, ...) or x(P(str), "expected %q", str)
    end
    Ci = function(p) -- ignore captures
        return p/function() return end
    end
    chain = function(patt, delimiter, s)
        return patt*((s==false and""or s and _^1 or _^0)*P(delimiter)*(s==false and""or s and _^1 or _^0)*patt)^0
    end
end

local patt = lpeg.P{
    file = _*x(V"module"+_)^0*_,
    module = (
        Cf(Ct""
            *   Cg(
                        Cc"label"
                    *   C(V"identifier")
                )
            *   _
            *   x("{")
            *   _
            *   Cg(
                        Cc"constantList"
                    *   Cf(Ct""
                            *   chain(
                                        Cg(
                                                "const"
                                            *   __
                                            *   C(V"identifier")
                                            *   __
                                            *   C(V"numeric")
                                        )
                                    ,   ","
                                )
                        )
                )
            *   Cg(
                        Cc"operationList"
                    *   Cf(Ct""
                            *   (
                                        (
                                                V"operation"
                                            *   _
                                        )^1
                                    +   ix("expected operation")
                                )
                        )
                )
            *   _
            *   x("}")
        )
    ),
    identifier = (
            (lo.alpha+"_")
        *   (lo.alnum+"_")^0
    ),
    number = (
            C(
                    P"-"^-1
                *   #(lo.digit+".")
                *   (
                            lo.digit^0
                        *   (
                                    "."
                                *   x(lo.digit^1, "expected digits after decimal point")
                            )^-1
                        *   (
                                    l.S"Ee"
                                *   (P"+" + "-")^-1
                                *   x(lo.digit^1, "expected digits after scientific notation initialiser")
                            )^-1
                    )
            )/tonumber
        *   P"f"^-1
    ),
    
}




