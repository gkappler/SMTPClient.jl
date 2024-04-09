
#Provide the message body as RFC5322 within an IO
function get_body(x...; k...)
    write_body(IOBuffer(),x...; k...)
end

write_body(io::IO, to, from,  subject, part; kw... ) =
    write_rfc5322mail(io, to, subject, part; from = from, kw...)

"""
        rfc5322mail(x...; k...)

Provide the message body as RFC5322 as a `String`.
"""
function rfc5322mail(x...; k...)
    String(take!(write_rfc5322mail(IOBuffer(),x...; k...)))
end

# """
#          write_body(io::IO,
#                     to::AbstractVector{<:AbstractString},
#                     from::AbstractString,
#                     subject::AbstractString,
#                     msg::MimeContent;
#                     attachments::AbstractVector = MimeContent[],
#                     k...
#                         )


# """
# function write_body(io::IO,
#                     to::AbstractVector{<:AbstractString},
#                     from::AbstractString,
#                     subject::AbstractString,
#                     msg::MimeContent;
#                     attachments::AbstractVector = MimeContent[],
#                     k...
#                         )
#     if msg.content_type == "text/html"
#         iob = IOBuffer()
#         @show txt = open(`html2text`, "w", iob) do io
#             print(io,@show msg.content)
#         end
#         pushfirst!(attachments, msg)
#         write_body(io,
#                    to,
#                    from,
#                    subject,
#                    String(take!(iob));
#                    attachments = Content[attachments...],
#                    k...
#                        )
#     else
#         error("cannot write mime type $(msg.content_type) as a message body")
#     end
# end

using Dates

write_rfc5322mail(io::IO, to::AbstractString, subject, msg; kw...) =
    write_rfc5322mail(io, [to], subject, msg; kw...)

write_rfc5322mail(io::IO, to::AbstractVector{<:AbstractString}, subject,msg::AbstractString; kw...) =
    write_rfc5322mail(io, to, subject, Plain(msg); kw... )

write_rfc5322mail(io::IO, to::AbstractVector{<:AbstractString}, subject, part::Markdown.MD; kw...) =
    write_rfc5322mail(io, to, subject,
                      MultiPart(:alternative,
                                Plain(Markdown.plain(part)),
                                HTML(Markdown.html(part)));
                      kw...)

function write_rfc5322mail(io::IO, to::AbstractVector{<:AbstractString}, subject, part::Content;
                       from::AbstractString = ENV["FROM"],
                       cc::AbstractVector{<:AbstractString} = String[],
                       bcc::AbstractVector{<:AbstractString} = String[],
                       replyto::AbstractString = "",
                       messageid::AbstractString="",
                       inreplyto::AbstractString="",
                       references::AbstractString="",
                       date::DateTime=now(),
                       headers = Pair{String,String}[]
                       )
    
    tz = mapreduce(
        x -> string(x, pad=2), *,
        divrem( div( ( now() - now(Dates.UTC) ).value, 60000, RoundNearest ), 60 )
    )
    date_ = join([Dates.format(date, "e, d u yyyy HH:MM:SS", locale="english"), tz], " +")

    print(io, "From: $from\r\n")
    print(io, "To: $(join(to, ", "))\r\n")
    if length(cc) > 0
        print(io, "Cc: $(join(cc, ", "))\r\n")
    end
    if length(bcc) > 0
        print(io, "Bcc: $(join(bcc, ", "))\r\n")
    end
    print(io, "Subject: $subject\r\n")
    if length(replyto) > 0
        print(io, "Reply-To: $replyto\r\n")
    end
    if length(references) > 0
        print(io, "References: ", references, "\r\n")
    end
    if length(inreplyto) > 0
        print(io, "In-Reply-To: ", inreplyto, "\r\n")
    end
    for (k,v) in headers
        print(io, "$k: ", v, "\r\n")
    end
    if length(messageid) > 0
        print(io, "Message-ID: ",
              "<" * messageid * ">", "\r\n")
    end
    #if length(parts) == 1
    print(io, "MIME-Version: 1.0\r\n")
    print(io, "Date: $date_\r\n")
    print(io, part)
        # print(io, "Content-Type: text/plain; charset=UTF-8\r\n")
        # print(io, "\r\n$msg\r\n\r\n")
    # else
    #     print(io, "MIME-Version: 1.0\r\n")
    #     print(io, "Content-Type: $contenttype; boundary=\"$boundary\"\r\n\r\n")
    #     print(io, "\r\n",
    #           "This is a message with multiple parts in MIME format.\r\n")
    #     msg != "" && print(io,
    #                        "--$boundary\r\n",
    #                        "$(get_mime_msg(msg))\r\n",
    #                        "--$boundary\r\n",
    #                        "\r\n")
    #     join(io,encode_attachment.(attachments, boundary), "\r\n")
    # end
    io
end
