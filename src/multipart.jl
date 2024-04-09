export HTML
# Content = Union{AbstractString,MimeContent,MultiPart}
abstract type Content end
@enum MultiPartSubType mixed alternative digest parallel

struct MultiPart <: Content
    subtype::MultiPartSubType
    boundary::String
    parts::Vector{Any}
end

function Base.show(io::IO, x::MultiPart)
    print(io, "Content-Type: multipart/$(x.subtype); boundary=\"$(x.boundary)\"\r\n\r\n")
    for p in x.parts
        print(io,"--$(x.boundary)\r\n")
        print(io,encode_attachment(p))
    end
    print(io,"--$(x.boundary)--\r\n")
end

MultiPart(subtype::Symbol, parts...) =
    MultiPart(if subtype == :mixed
                  mixed 
              elseif subtype == :alternative
                  alternative
              elseif subtype == :digest
                  digest
              elseif subtype == :parallel
                  parallel
              else
                  error("unsupported subtype $subtype")
              end,
              "JS-" * join(rand(collect(vcat('0':'9','A':'Z','a':'z')), 5)),
              [parts...]
              )


struct Plain <: Content
    content_transfer_encoding::String
    content::String
    Plain(msg) =
        new("",msg) # replace(msg, r"[ \r\n\t]+$" => "\r\n", r"^[\r\n\t]+" => "")
end

function Base.show(io::IO, x::Plain; charset="UTF-8")
    print(io, "Content-Type: text/plain; charset=\"$charset\"\r\n\r\n")
    print(io, x.content)
end

mimesymbol(x::MIME{mt}) where mt =
    mt

struct MIMEContent{content_type <: MIME} <: Content
    content_disposition::String
    content_transfer_encoding::String
    filename::String
    content::String
    function MIMEContent(content_disposition, content_transfer_encoding, content_type::MIME, filename, content)
        new{typeof(content_type)}(content_disposition,content_transfer_encoding, filename, content)
    end
    function MIMEContent(content_disposition, content_type::MIME, filename, content)
        new{typeof(content_type)}(content_disposition,"base64", filename, content)
    end
end


                          # if startswith(string(mimesymbol(content_type)),"text/")
                          #     "quoted-printable"
                          # else
                          #     "base64"
                          # end
MIMEContent(content_disposition, content_type::AbstractString, filename, content) =
    MIMEContent(content_disposition, MIME(content_type), filename, content)

function MIMEContent(filename, content)
    filename_ext = split(filename, '.')[end]

    if haskey(mime_types, filename_ext)
        content_type = mime_types[filename_ext]
    else
        content_type = "application/octet-stream"
    end

    if haskey(mime_types, filename_ext) && startswith(mime_types[filename_ext], "image")
        content_disposition = "inline"
    else
        content_disposition = "attachment"
    end
    MIMEContent(content_disposition, content_type, filename, content)
end

HTML(x; content_disposition = "inline") = MIMEContent(content_disposition,"text/html","",x)
HTML(filename, x) = MIMEContent("attachment","text/html",filename,x)
#HTML

function encode_content(m)
    if lowercase(m.content_transfer_encoding) == "base64"
        io = IOBuffer()
        iob64_encode = Base64EncodePipe(io)
        write(iob64_encode, m.content)
        close(iob64_encode)
        join(breakstring(String(take!(io)); columns = 76), "\r\n")
    elseif lowercase(m.content_transfer_encoding) == "quoted-printable"
        join([join(breakstring(line; columns = 75), "=\r\n")
              for line in split(m.content,"\n")], "\r\n")
    elseif lowercase(m.content_transfer_encoding) in [ "", "binary" ]
        m.content
    else
        error("unsupported content_transfer_encoding $(m.content_transfer_encoding)")
    end
end

function encode_attachment(m::MIMEContent{<:MIME{content_type}}) where content_type
    cts = encode_content(m)
    encoded_str =  "Content-Type: $(content_type); charset=UTF-8\r\n" *
        "Content-Disposition: $(m.content_disposition);\r\n" *
        if m.filename != ""
            "    filename=$(basename(m.filename))\r\n" *
            "Content-Description: $(basename(m.filename))\r\n"
        else
            ""
        end *
        (m.content_transfer_encoding =="" ? "" : "Content-Transfer-Encoding: $(m.content_transfer_encoding)\r\n") *
        "\r\n" *
        "$cts\r\n"
    return encoded_str
end

function Base.show(io::IO, x::MIMEContent)
    print(io, encode_attachment(x))
end

# @enum ContentTypes text multipart message image audio video application

# struct ContentType
#     type::String   # "X-..." https://www.ietf.org/rfc/rfc1341.pdf
#     subtype::String
#     parameter::Dict{String,String}
# end
export MultiPart, Plain

function encode_attachment(x::Content)
    string(x)
end

function encode_attachment(x::Plain)
    "Content-Type: text/plain; charset=UTF-8\r\n" *
        (x.content_transfer_encoding =="" ? "" : "Content-Transfer-Encoding: $(x.content_transfer_encoding)\r\n") *
        "\r\n" *
        encode_content(x)
end

"""
        encode_attachment(filename::String)

Load file `filename` contents, base64 encode it.
Returns encoded String with headers 
- `Content-Type` according to file extension.
- `Content-Disposition`  is `inline` for images, `attachment` otherwise.
- `Content-ID` is `basename(filename)`
"""
function encode_attachment(filename::String)
    io = IOBuffer()
    iob64_encode = Base64EncodePipe(io)
    open(filename, "r") do f
        write(iob64_encode, f)
    end
    close(iob64_encode)

    encode_attachment(MIMEContent(filename, String(take!(io))))
    # filename_ext = split(filename, '.')[end]
    # if haskey(mime_types, filename_ext)
    #     content_type = mime_types[filename_ext]
    # else
    #     content_type = "application/octet-stream"
    # end
    # if haskey(mime_types, filename_ext) && startswith(mime_types[filename_ext], "image")
    #     content_disposition = "inline"
    # else
    #     content_disposition = "attachment"
    # end
    # cts = join(breakstring(; columns = 76), "\r\n")
    # encoded_str = 
    #     "Content-Disposition: $content_disposition;\r\n" *
    #     "    filename=\"$(basename(filename))\"\r\n" *
    #     "Content-Type: $content_type;\r\n" *
    #     "    name=\"$(basename(filename))\"\r\n" *
    #     "Content-ID: <$(basename(filename))>\r\n" *
    #     "Content-Transfer-Encoding: base64\r\n" *
    #     "\r\n" *
    #     "$cts\r\n"
    # return encoded_str
end

# function encode_attachment(html::HTML)
#     encoded_str = 
#         "$(get_mime_msg(html,Val{:html}()))\r\n"
#     return encoded_str
# end

# function encode_attachment(x)
#     encoded_str =   "$(x)\r\n"
#     return encoded_str
# end

# See https://www.w3.org/Protocols/rfc1341/7_1_Text.html about charset
# function get_mime_msg(message::String, ::Val{:plain}, charset::String = "UTF-8")
#     msg = 
#         "Content-Type: text/plain; charset=\"$charset\"\r\n" *
#         "Content-Transfer-Encoding: quoted-printable\r\n\r\n" *
#         "$message\r\n"
#     return msg
# end

# get_mime_msg(message::String, ::Val{:utf8}) =
#     get_mime_msg(message, Val(:plain), "UTF-8")

# get_mime_msg(message::String, ::Val{:usascii}) =
#     get_mime_msg(message, Val(:plain), "US-ASCII")

# get_mime_msg(message::String) = get_mime_msg(message, Val(:utf8))

# # get_mime_msg(message::HTML, ::Val{:html}) =
# #     get_mime_msg(message.content, Val(:html))
    
# function get_mime_msg(message::AbstractString, ::Val{:html})
#     msg = 
#         "Content-Type: text/html; charset=\"UTF-8\"\r\n" *
#         "Content-Transfer-Encoding: quoted-printable;\r\n" *
#         "\r\n" *
#         #"<html>\r\n<body>" *
#         message * "\r\n"# *
#         #"</body>\r\n</html>"
#     return msg
# end

# #get_mime_msg(message::HTML) = get_mime_msg(message.content, Val(:html))

# get_mime_msg(message::Markdown.MD) = get_mime_msg(Markdown.html(message), Val(:html))
