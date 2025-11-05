
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

write_rfc5322mail(io::IO, to::AbstractVector, subject,msg::AbstractString; kw...) =
    write_rfc5322mail(io, to, subject, PlainContent(msg); kw... )

write_rfc5322mail(io::IO, to::AbstractVector, subject, part::Markdown.MD; kw...) =
    write_rfc5322mail(io, to, subject,
                      MultiPart(:alternative,
                                PlainContent(Markdown.plain(part)),
                                HTMLContent(Markdown.html(part)));
                      kw...)

references_str(x::Missing) = missing
references_str(x::Number) = "<$x>"
references_str(x::AbstractString) = isempty(x) ? "" : "<$x>"
references_str(x::AbstractVector) = isempty(x) ? "" : "<" * join(x,",") * ">"

write_rfc5322header(io, key::AbstractString, value::AbstractString) = 
    value != "" && print(io, "$key: $value\r\n")

capitalize(x) = uppercase(x[1]) * lowercase(x[2:end])
write_rfc5322header(io, key::Symbol, value::AbstractString) = 
    write_rfc5322header(io, join([capitalize(w) for w in split("$key", "_")], "-"), value) 

write_rfc5322header(io, key::AbstractString, value::Missing) = nothing

function write_rfc5322mail(io::IO, to::AbstractVector, subject, part::Content;
                       from = ENV["FROM"],
                       cc = String[],
                       bcc = String[],
                       replyto = "",
                       messageid="",
                       inreplyto="",
                       references="",
                       date::DateTime=now(),
                           keywords = String[],
                           headers...

                           )
    
    tz = mapreduce(
        x -> string(x, pad=2), *,
        divrem( div( ( now() - now(Dates.UTC) ).value, 60000, RoundNearest ), 60 )
    )
    date_ = join([Dates.format(date, "e, d u yyyy HH:MM:SS", locale="english"), tz], " +")

    write_rfc5322header(io, "Date", date_)
    write_rfc5322header(io, "From", from)
    write_rfc5322header(io, "Reply-To",replyto)
    write_rfc5322header(io, "To", join(to, ", "))
    write_rfc5322header(io, "Cc", join(cc, ", "))
    write_rfc5322header(io, "Bcc", join(bcc, ", "))
    print(io, "Subject: $subject\r\n")
    !isempty(keywords) && push!(headers, "X-Keywords" => join(replace.(keywords,","=>"-"), ","))
    write_rfc5322header(io, "In-Reply-To", references_str(inreplyto))
    write_rfc5322header(io, "References", references_str(references))
    write_rfc5322header(io, "Message-ID", references_str(messageid))
    for (k,v) in headers
        write_rfc5322header(io, k, v)
    end
    #if length(parts) == 1
    print(io, "MIME-Version: 1.0\r\n")
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
