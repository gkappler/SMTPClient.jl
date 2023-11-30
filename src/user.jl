export HTML
struct MimeContent{mime<:MIME}
    filename::String
    content::String
end
HTML = MimeContent{MIME{Symbol("text/html")}}
Attachment = Union{AbstractString,MimeContent}

MimeContent{MIME{Symbol("text/html")}}(x::AbstractString) = MimeContent{MIME{Symbol("text/html")}}("",x)

function encode_attachment(filename::String, boundary::String)
    io = IOBuffer()
    iob64_encode = Base64EncodePipe(io)
    open(filename, "r") do f
        write(iob64_encode, f)
    end
    close(iob64_encode)

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

    # Some email clients, like Spark Mail, have problems when the attachment
    # encoded string is very long. This code breaks the payload into lines with
    # 75 characters, avoiding those problems.
    raw_attachment = String(take!(io))
    buf = IOBuffer()
    char_count = 0

    for c in raw_attachment
        write(buf, c)
        char_count += 1

        if char_count == 75
            write(buf, "\r\n")
            char_count = 0
        end
    end

    encoded_str =
        "Content-Disposition: $content_disposition;\r\n" *
        "    filename=\"$(basename(filename))\"\r\n" *
        "Content-Type: $content_type;\r\n" *
        "    name=\"$(basename(filename))\"\r\n" *
        "Content-ID: <$(basename(filename))>\r\n" *
        "Content-Transfer-Encoding: base64\r\n" *
        "\r\n" *
        "$(String(take!(buf)))\r\n"
    return encoded_str
end

function encode_attachment(html::HTML, boundary::String)
    encoded_str = 
        "--$boundary\r\n" *
        "$(get_mime_msg(html,Val{:html}()))\r\n" *
        "--$boundary\r\n"
    return encoded_str
end

function encode_attachment(m::MimeContent{MIME{mime}}, boundary::String) where mime
    io = IOBuffer()
    iob64_encode = Base64EncodePipe(io)
    write(iob64_encode, m.content)
    close(iob64_encode)

    filename_ext = split(m.filename, '.')[end]

    if haskey(mime_types, filename_ext)
        content_type = mime_types[filename_ext]
    else
        content_type = "$mime"
    end

    if haskey(mime_types, filename_ext) && startswith(mime_types[filename_ext], "image")
        content_disposition = "inline"
    else
        content_disposition = "attachment"
    end

    encoded_str = 
        "--$boundary\r\n" *
        "Content-Type: $content_type;\r\n" *
        "Content-Disposition: $content_disposition;\r\n" *
        "    filename=$(basename(m.filename))\r\n" *
        "Content-Transfer-Encoding: base64\r\n" *
        "Content-Description: $(basename(m.filename))\r\n" *
        "\r\n" *
        "$(String(take!(io)))\r\n" *
        "--$boundary\r\n"
    return encoded_str
end

# See https://www.w3.org/Protocols/rfc1341/7_1_Text.html about charset
function get_mime_msg(message::String, ::Val{:plain}, charset::String = "UTF-8")
    msg = 
        "Content-Type: text/plain; charset=\"$charset\"\r\n" *
        "Content-Transfer-Encoding: quoted-printable\r\n\r\n" *
        "$message\r\n"
    return msg
end

get_mime_msg(message::String, ::Val{:utf8}) =
    get_mime_msg(message, Val(:plain), "UTF-8")

get_mime_msg(message::String, ::Val{:usascii}) =
    get_mime_msg(message, Val(:plain), "US-ASCII")

get_mime_msg(message::String) = get_mime_msg(message, Val(:utf8))


function get_mime_msg(message, ::Val{:html})
    msg = 
        "Content-Type: text/html;\r\n" *
        "Content-Transfer-Encoding: 7bit;\r\n\r\n" *
        "\r\n" *
        "<html>\r\n<body>" *
        message *
        "</body>\r\n</html>"
    return msg
end

get_mime_msg(message::HTML) = get_mime_msg(message.content, Val(:html))

get_mime_msg(message::Markdown.MD) = get_mime_msg(Markdown.html(message), Val(:html))

#Provide the message body as RFC5322 within an IO
function get_body(x...; k...)
    write_body(IOBuffer(),x...; k...)
end

function write_body(io::IO,
                    to::AbstractVector{<:AbstractString},
                    from::AbstractString,
                    subject::AbstractString,
                    msg::HTML;
                    attachments::AbstractVector{<:Attachment} = Attachment[],
                    k...
                    )
    iob = IOBuffer()
    @show txt = open(`html2text`, "w", iob) do io
        print(io,@show msg.content)
    end
    attachments = Attachment[attachments...]
    pushfirst!(attachments, msg)
    write_body(io,
               to,
               from,
               subject,
               String(take!(iob));
               attachments = attachments,
               k...
                   )
end

using Dates

function write_body(io::IO,
                    to::AbstractVector{<:AbstractString},
                    from::AbstractString,
                    subject::AbstractString,
                    msg::AbstractString;
                    cc::AbstractVector{<:AbstractString} = String[],
                    bcc::AbstractVector{<:AbstractString} = String[],
                    replyto::AbstractString = "",
                    messageid::AbstractString="",
                    inreplyto::AbstractString="",
                    references::AbstractString="",
                    date::DateTime=now(),
                    attachments::AbstractVector{<:Attachment} = Attachment[],
                    boundary = "Julia_SMTPClient-" * join(rand(collect(vcat('0':'9','A':'Z','a':'z')), 40))
                    )
    
    tz = mapreduce(
        x -> string(x, pad=2), *,
        divrem( div( ( now() - now(Dates.UTC) ).value, 60000, RoundNearest ), 60 )
    )
    date_ = join([Dates.format(date, "e, d u yyyy HH:MM:SS", locale="english"), tz], " +")

    print(io, "From: $from\r\n")
    print(io, "Date: $date_\r\n")
    print(io, "Subject: $subject\r\n")
    if length(cc) > 0
        print(io, "Cc: $(join(cc, ", "))\r\n")
    end
    if length(bcc) > 0
        print(io, "Bcc: $(join(bcc, ", "))\r\n")
    end
    if length(replyto) > 0
        print(io, "Reply-To: $replyto\r\n")
    end
    print(io, "To: $(join(to, ", "))\r\n")
    if length(references) > 0
        print(io, "References: ", references, "\r\n")
    end
    if length(inreplyto) > 0
        print(io, "In-Reply-To: ", inreplyto, "\r\n")
    end
    if length(messageid) > 0
        print(io, "Message-ID: ",
              "<" * messageid * ">", "\r\n")
    end
    msg = replace(msg, r"[ \r\n\t]+$" => "\r\n", r"^[\r\n\t]+" => "")
    if length(attachments) == 0
        print(io, "Content-Type: text/plain; charset=UTF-8\r\n")
        print(io, "MIME-Version: 1.0\r\n")
        print(io, "\r\n$msg\r\n\r\n")
    else
        print(io, "Content-Type: multipart/mixed; boundary=\"$boundary\"\r\n\r\n")
        print(io, "MIME-Version: 1.0\r\n",
              "\r\n",
              "This is a message with multiple parts in MIME format.\r\n",
              "--$boundary\r\n",
              "$(get_mime_msg(msg))\r\n",
              "--$boundary\r\n",
              "\r\n")
        join(io,encode_attachment.(attachments, boundary), "\r\n")
    end
    io
end
