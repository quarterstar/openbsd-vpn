def parse_comma_arg(arg: str) -> list[str]:
    strs = []
    buf = ''

    for i, c in enumerate(arg):
        if c == ',':
            strs.append(buf)
            buf = ''
        else:
            buf += c

        if i == len(arg) - 1:
            strs.append(buf)

    return strs
