
"""
        breakstring(x; columns=2)

break up `x` into substrings of length `columns`.
"""
function breakstring(x; columns=2)
    out = SubString{String}[]
    offset = 1
    while length(x) - offset >= columns
        push!(out,x[offset:nextind(x,offset,columns-1)])
        offset = nextind(x,offset,columns)
        #x = x[(columns+1):end]
    end
    push!(out,x[offset:end])
    out
end

@deprecate multiline(x;limit) breakstring(x; columns = limit)


macro ce_curl(f, handle, args...)
  local esc_args = [esc(arg) for arg in args]
  quote
    cc = $(esc(f))($(esc(handle)), $(esc_args...))

    if cc != CURLE_OK
      err = unsafe_string(curl_easy_strerror(cc))
      error(string($f) * "() failed: " * err)
    end
  end
end

macro ce_curlm(f, handle, args...)
  local esc_args = [esc(arg) for arg in args]
  quote
    cc = $(esc(f))($(esc(handle)), $(esc_args...))

    if cc != CURLM_OK
      err = unsafe_string(curl_multi_strerror(cc))
      error(string($f) * "() failed: " * err)
    end
  end
end
