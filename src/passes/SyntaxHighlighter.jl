module SyntaxHighlighter

using Compat
import Compat.String

using Tokenize
using Tokenize.Tokens
import Tokenize.Tokens: Token, kind, exactkind, iskeyword

using Crayons

import OhMyREPL: add_pass!, PASS_HANDLER

type ColorScheme
    symbol::Crayon
    comment::Crayon
    string::Crayon
    call::Crayon
    op::Crayon
    keyword::Crayon
    text::Crayon
    function_def::Crayon
    error::Crayon
    argdef::Crayon
    _macro::Crayon
    number::Crayon
end

symbol!(cs, crayon::Crayon) = cs.symbol = crayon
comment!(cs, crayon::Crayon) = cs.comment = crayon
string!(cs, crayon::Crayon) = cs.string = crayon
call!(cs, crayon::Crayon) = cs.call = crayon
op!(cs, crayon::Crayon) = cs.op = crayon
keyword!(cs, crayon::Crayon) = cs.keyword = crayon
text!(cs, crayon::Crayon) = cs.text = crayon
function_def!(cs, crayon::Crayon) = cs.function_def = crayon
error!(cs, crayon::Crayon) = cs.error = crayon
argdef!(cs, crayon::Crayon) = cs.argdef = crayon
macro!(cs, crayon::Crayon) = cs._macro = crayon
number!(cs, crayon::Crayon) = cs.number = crayon

function Base.show(io::IO, cs::ColorScheme)
    for n in fieldnames(cs)
        crayon = getfield(cs, n)
        print(io, crayon, "█ ", inv(crayon))
    end
    print(io, Crayon(foreground = :default))
end

ColorScheme() = ColorScheme([Crayon() for _ in 1:length(fieldnames(ColorScheme))]...)

function _create_juliadefault()
    cs = ColorScheme()
    symbol!(cs, Crayon(bold = true))
    comment!(cs, Crayon(bold = true))
    string!(cs, Crayon(bold = true))
    call!(cs, Crayon(bold = true))
    op!(cs, Crayon(bold = true))
    keyword!(cs, Crayon(bold = true))
    text!(cs, Crayon(bold = true))
    macro!(cs, Crayon(bold = true))
    function_def!(cs, Crayon(bold = true))
    error!(cs, Crayon(bold = true))
    argdef!(cs, Crayon(bold = true))
    number!(cs, Crayon(bold = true))
    return cs
end


# Try to represent the Monokai colorscheme.
function _create_monokai()
    cs = ColorScheme()
    symbol!(cs, Crayon(foreground = :magenta))
    comment!(cs, Crayon(foreground = :dark_gray))
    string!(cs, Crayon(foreground = :yellow))
    call!(cs, Crayon(foreground = :cyan))
    op!(cs, Crayon(foreground = :light_red))
    keyword!(cs, Crayon(foreground = :light_red))
    text!(cs, Crayon(foreground = :default))
    macro!(cs, Crayon(foreground = :cyan))
    function_def!(cs, Crayon(foreground = :green))
    error!(cs, Crayon(foreground = :default))
    argdef!(cs, Crayon(foreground = :cyan))
    number!(cs, Crayon(foreground = :magenta))
    return cs
end

function _create_monokai_256()
    cs = ColorScheme()
    symbol!(cs, Crayon(foreground = 141)) # purpleish
    comment!(cs, Crayon(foreground = 60)) # greyish
    string!(cs, Crayon(foreground = 208)) # beigish
    call!(cs, Crayon(foreground = 81)) # cyanish
    op!(cs, Crayon(foreground = 197)) # redish
    keyword!(cs, Crayon(foreground = 197)) # redish
    text!(cs, Crayon(foreground = :default))
    macro!(cs, Crayon(foreground = 208)) # cyanish
    function_def!(cs, Crayon(foreground = 148))
    error!(cs, Crayon(foreground = :default))
    argdef!(cs, Crayon(foreground = 81))  # cyanish
    number!(cs, Crayon(foreground = 141)) # purpleish
    return cs
end


function _create_boxymonokai_256()
    cs = ColorScheme()
    symbol!(cs, Crayon(foreground = 148))
    comment!(cs, Crayon(foreground = 95))
    string!(cs, Crayon(foreground = 148))
    call!(cs, Crayon(foreground = 81))
    op!(cs, Crayon(foreground = 158))
    keyword!(cs, Crayon(foreground = 141))
    text!(cs, Crayon(foreground = :default))
    macro!(cs, Crayon(foreground = 81))
    function_def!(cs, Crayon(foreground = 81))
    error!(cs, Crayon(foreground = :default))
    argdef!(cs, Crayon(foreground = 186))
    number!(cs, Crayon(foreground = 208))
    return cs
end

type SyntaxHighlighterSettings
    active::ColorScheme
    schemes::Dict{String, ColorScheme}
end


function Base.show(io::IO, sh::SyntaxHighlighterSettings)
    first = true
    l = maximum(x->length(x), keys(sh.schemes))
    for (k, v) in sh.schemes
        if !first
            print(io, "\n\n")
        end
        first = false
        print(io, rpad(k, l+1, " "))
        print(io, v)
    end
    println(io)
end

function SyntaxHighlighterSettings()
    def = _create_juliadefault()
    d = Dict("JuliaDefault" => def)
    SyntaxHighlighterSettings(def, d)
end

SYNTAX_HIGHLIGHTER_SETTINGS = SyntaxHighlighterSettings()

add!(sh::SyntaxHighlighterSettings, name::String, scheme::ColorScheme) = sh.schemes[name] = scheme
add!(name::String, scheme::ColorScheme) = add!(SYNTAX_HIGHLIGHTER_SETTINGS, name, scheme)
activate!(sh::SyntaxHighlighterSettings, name::String) = sh.active = sh.schemes[name]

add!(SYNTAX_HIGHLIGHTER_SETTINGS, "Monokai256", _create_monokai_256())
add!(SYNTAX_HIGHLIGHTER_SETTINGS, "Monokai16", _create_monokai())
add!(SYNTAX_HIGHLIGHTER_SETTINGS, "BoxyMonokai256", _create_boxymonokai_256())
# Added by default
# add!(SYNTAX_HIGHLIGHTER_SETTINGS, "JuliaDefault", _create_juliadefault())

if !is_windows()
    activate!(SYNTAX_HIGHLIGHTER_SETTINGS, "Monokai256")
else
    activate!(SYNTAX_HIGHLIGHTER_SETTINGS, "Monokai16")
end
add_pass!(PASS_HANDLER, "SyntaxHighlighter", SYNTAX_HIGHLIGHTER_SETTINGS, false)


@compat function (highlighter::SyntaxHighlighterSettings)(crayons::Vector{Crayon}, tokens::Vector{Token}, ::Int)
    cscheme = highlighter.active
    prev_t = Tokens.Token()
    for (i, t) in enumerate(tokens)
        # a::x
        if exactkind(prev_t) == Tokens.DECLARATION
            crayons[i-1] = cscheme.argdef
            crayons[i] = cscheme.argdef
        # :foo
        elseif kind(t) == Tokens.IDENTIFIER && exactkind(prev_t) == Tokens.COLON
            crayons[i-1] = cscheme.symbol
            crayons[i] = cscheme.symbol
        # function
        elseif iskeyword(kind(t))
            if kind(t) == Tokens.TRUE || kind(t) == Tokens.FALSE
                crayons[i] = cscheme.symbol
            else
                crayons[i] = cscheme.keyword
            end
        # "foo"
        elseif kind(t) == Tokens.STRING || kind(t) == Tokens.TRIPLE_STRING || kind(t) == Tokens.CHAR
            crayons[i] = cscheme.string
        # * -
        elseif Tokens.isoperator(kind(t))
            crayons[i] = cscheme.op
        # #= foo =#
        elseif kind(t) == Tokens.COMMENT
            crayons[i] = cscheme.comment
        # function f(...)
        elseif kind(t) == Tokens.LPAREN && kind(prev_t) == Tokens.IDENTIFIER
            crayons[i-1] = cscheme.call
             # function f(...)
            if i > 3 && kind(tokens[i-2]) == Tokens.WHITESPACE && exactkind(tokens[i-3]) == Tokens.FUNCTION
                crayons[i-1] = cscheme.function_def
            end
        # @fdsafds
        elseif kind(t) == Tokens.IDENTIFIER && exactkind(prev_t) == Tokens.AT_SIGN
            crayons[i-1] = cscheme._macro
            crayons[i] = cscheme._macro
        # 2] = 32.32
        elseif kind(t) == Tokens.INTEGER || kind(t) == Tokens.FLOAT
            crayons[i] = cscheme.number
        elseif kind(t) == Tokens.WHITESPACE
            crayons[i] = Crayon()
        else
            crayons[i] = cscheme.text
        end
        prev_t = t
    end
    return
end

end


