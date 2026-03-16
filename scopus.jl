# transform Scopus CSV export into markdown list

function parse_csv_line(line::AbstractString)
    fields = String[]
    current = IOBuffer()
    in_quotes = false
    
    for char in line
        if char == '"'
            in_quotes = !in_quotes
        elseif char == ',' && !in_quotes
            push!(fields, String(take!(current)))
        else
            write(current, char)
        end
    end
    push!(fields, String(take!(current)))
    
    return fields
end

function format_authors(authors_str::AbstractString)
    parts = String[]
    current = ""
    
    for segment in split(authors_str, ", ")
        if isempty(current)
            current = segment
        else
            # check if previous part ends with an initial
            if occursin(r"\.$", current)
                push!(parts, current)
                current = segment
            else
                current = current * ", " * segment
            end
        end
    end
    if !isempty(current)
        push!(parts, current)
    end

    formatted = String[]
    for author in parts
        # split into lastname and initials
        m = match(r"^(.+?)\s+([A-Z]\.(?:[A-Z]\.)*)$", strip(author))
        if m !== nothing
            lastname = m.captures[1]
            initials = m.captures[2]
            push!(formatted, "$initials $lastname")
        else
            push!(formatted, strip(author))
        end
    end
    
    return join(formatted, ", ")
end

function format_journal(source, volume, issue, art_no, page_start, page_end)
    parts = ["**$source**"]
    
    if !isempty(volume)
        push!(parts, " $volume")
    end
    
    if !isempty(issue)
        parts[end] = parts[end] * "($issue)"
    end
    
    if !isempty(art_no)
        push!(parts, ", $art_no")
    elseif !isempty(page_start) && !isempty(page_end)
        push!(parts, ", $(page_start)–$(page_end)")
    elseif !isempty(page_start)
        push!(parts, ", $page_start")
    end
    
    return join(parts, "")
end

function format_paper(fields)
    # columns: Authors,Title,Year,Source title,Volume,Issue,Art. No.,Page start,Page end,Page count,DOI,Link
    authors = format_authors(fields[1])
    title = fields[2]
    year = fields[3]
    source = fields[4]
    volume = fields[5]
    issue = fields[6]
    art_no = fields[7]
    page_start = fields[8]
    page_end = fields[9]
    doi = fields[11]
    
    journal = format_journal(source, volume, issue, art_no, page_start, page_end)
    doi_link = "[$doi](https://doi.org/$doi)"

    return "- $authors. *$title*. $journal ($year). $doi_link"
end

function main()
    csv_path = joinpath(@__DIR__, "content", "scopus.csv")
    lines = readlines(csv_path)
    
    # parse lines into papers
    papers = []
    for line in lines[2:end]
        if !isempty(strip(line))
            fields = parse_csv_line(line)
            year = parse(Int, fields[3])
            push!(papers, (year=year, fields=fields))
        end
    end
    
    # sort papers by year
    sort!(papers, by=p -> p.year, rev=true)

    # generate new list of papers
    paper_list = "## Published papers\n\n"
    for paper in papers
        paper_list *= format_paper(paper.fields) * "\n"
    end
    
    regex = r"## Published papers.*?(?=\n## |\Z)"s
    
    # change the content of pubs.qmd
    content = read("pubs.qmd", String)
    if occursin(regex, content)
        content = replace(content, regex => paper_list)
    else
        content *= "\n" * paper_list
    end

    write("pubs.qmd", content)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
