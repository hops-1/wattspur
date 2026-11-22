#!/usr/bin/env python3
"""Word and PDF of the App Review video script (B-318), from docs/appstore/REVIEW-VIDEO.html into dist/.

    scripts/review-video-docs.py

Standard library only. textutil cannot be used for Word: its .docx export drops every table. The PDF
needs Google Chrome. The source may use h1-h3, p, ul/ol/li, table, b and code; nothing else is styled.
"""
import subprocess
import tempfile
import zipfile
from html.parser import HTMLParser
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs/appstore/REVIEW-VIDEO.html"
OUT = ROOT / "dist"
NAME = "Wattspur-Review-Video"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
TEXT_WIDTH = 10204  # A4 with 15 mm margins, in twentieths of a point


def run(text, bold=False, code=False, english=False):
    style = ""
    if code:
        style += '<w:rFonts w:ascii="Menlo" w:hAnsi="Menlo"/>'
    if bold:
        style += "<w:b/>"
    if code:
        style += '<w:sz w:val="17"/>'
    if english:
        style += '<w:lang w:val="en-US"/>'
    return f'<w:r><w:rPr>{style}</w:rPr><w:t xml:space="preserve">{escape(text)}</w:t></w:r>'


def paragraph(runs, style="Normal", number=None, keep=False):
    props = f'<w:pStyle w:val="{style}"/>'
    if keep:
        props += "<w:keepNext/>"
    if number:
        props += f'<w:numPr><w:ilvl w:val="0"/><w:numId w:val="{number}"/></w:numPr>'
    return f"<w:p><w:pPr>{props}</w:pPr>{''.join(runs)}</w:p>"


def table(rows):
    count = len(rows[0])
    if count == 3:
        widths = [3300, 4604, 2300]
    elif rows[0][0]["label"]:
        widths = [2750, TEXT_WIDTH - 2750]
    else:
        widths = [TEXT_WIDTH - 1700, 1700]
    side = 'w:val="single" w:sz="4" w:space="0" w:color="B8B8BD"'
    borders = "".join(f"<w:{s} {side}/>" for s in ("top", "left", "bottom", "right", "insideH", "insideV"))
    xml = (f'<w:tbl><w:tblPr><w:tblW w:w="{TEXT_WIDTH}" w:type="dxa"/><w:tblBorders>{borders}</w:tblBorders>'
           '<w:tblLayout w:type="fixed"/><w:tblCellMar><w:left w:w="90" w:type="dxa"/>'
           '<w:right w:w="90" w:type="dxa"/></w:tblCellMar></w:tblPr><w:tblGrid>'
           + "".join(f'<w:gridCol w:w="{w}"/>' for w in widths) + "</w:tblGrid>")
    for index, cells in enumerate(rows):
        header = "<w:tblHeader/>" if cells[0]["header"] else ""
        xml += f"<w:tr><w:trPr><w:cantSplit/>{header}</w:trPr>"
        for width, cell in zip(widths, cells):
            shade = '<w:shd w:val="clear" w:color="auto" w:fill="F2F2F4"/>' if cell["header"] or cell["label"] else ""
            # A scene's four rows stay on one page.
            keep = len(rows) <= 5 and index < len(rows) - 1
            xml += (f'<w:tc><w:tcPr><w:tcW w:w="{width}" w:type="dxa"/>{shade}</w:tcPr>'
                    f'{paragraph(cell["runs"], "Cell", keep=keep)}</w:tc>')
        xml += "</w:tr>"
    return xml + "</w:tbl>" + paragraph([], "Gap")


class Converter(HTMLParser):
    def __init__(self):
        super().__init__()
        self.body = []
        self.runs = None  # the runs of the open block, None outside one
        self.ordered = []  # numbering ids of the ordered lists
        self.number = None
        self.rows = []
        self.cell = None
        self.bold = self.code = 0

    def handle_starttag(self, tag, attrs):
        kind = dict(attrs).get("class")
        if tag in ("h1", "h2", "h3", "p", "li"):
            self.runs = []
        elif tag == "ul":
            self.number = 1
        elif tag == "ol":
            self.number = len(self.ordered) + 2
            self.ordered.append(self.number)
        elif tag == "table":
            self.rows = []
        elif tag == "tr":
            self.rows.append([])
        elif tag in ("td", "th"):
            self.runs = []
            self.cell = {"runs": self.runs, "header": tag == "th", "label": kind == "label", "say": kind == "say"}
            self.rows[-1].append(self.cell)
        elif tag == "b":
            self.bold += 1
        elif tag == "code":
            self.code += 1

    def handle_endtag(self, tag):
        if tag in ("h1", "h2", "h3"):
            self.body.append(paragraph(self.runs, {"h1": "Title", "h2": "Heading1", "h3": "Heading2"}[tag]))
        elif tag == "p":
            self.body.append(paragraph(self.runs))
        elif tag == "li":
            self.body.append(paragraph(self.runs, "Item", self.number))
        elif tag in ("ul", "ol"):
            self.number = None
        elif tag == "table":
            self.body.append(table(self.rows))
        elif tag == "b":
            self.bold -= 1
        elif tag == "code":
            self.code -= 1
        if tag in ("h1", "h2", "h3", "p", "li", "td", "th"):
            self.runs = self.cell = None

    def handle_data(self, data):
        if self.runs is None:
            return
        cell = self.cell or {}
        bold = self.bold or cell.get("header") or cell.get("label") or cell.get("say")
        self.runs.append(run(data, bool(bold), self.code > 0, bool(cell.get("say"))))


def styles():
    def style(name, title, size, before=0, after=60, bold=False, keep=False):
        return (f'<w:style w:type="paragraph" w:styleId="{name}"><w:name w:val="{title}"/><w:qFormat/>'
                f'<w:pPr>{"<w:keepNext/>" if keep else ""}<w:spacing w:before="{before}" w:after="{after}"/></w:pPr>'
                f'<w:rPr>{"<w:b/>" if bold else ""}<w:sz w:val="{size}"/></w:rPr></w:style>')
    return (f'<w:styles xmlns:w="{W}"><w:docDefaults><w:rPrDefault><w:rPr>'
            '<w:rFonts w:ascii="Helvetica" w:hAnsi="Helvetica" w:cs="Helvetica"/><w:lang w:val="de-DE"/>'
            "</w:rPr></w:rPrDefault></w:docDefaults>"
            + style("Normal", "Normal", 21) + style("Title", "Title", 38, after=120, bold=True)
            + style("Heading1", "heading 1", 28, 280, 100, True, True)
            + style("Heading2", "heading 2", 23, 200, 60, True, True)
            + style("Item", "List Paragraph", 21, after=40) + style("Cell", "Table Cell", 20, 40, 40)
            + style("Gap", "Table Gap", 10, after=40) + "</w:styles>")


def numbering(ordered):
    def level(number, kind, text):
        return (f'<w:abstractNum w:abstractNumId="{number}"><w:lvl w:ilvl="0"><w:start w:val="1"/>'
                f'<w:numFmt w:val="{kind}"/><w:lvlText w:val="{text}"/>'
                '<w:pPr><w:ind w:left="340" w:hanging="340"/></w:pPr></w:lvl></w:abstractNum>')
    # A list of its own for each <ol>, so every one starts at 1.
    return (f'<w:numbering xmlns:w="{W}">' + level(1, "bullet", "•")
            + "".join(level(n, "decimal", "%1.") for n in ordered)
            + "".join(f'<w:num w:numId="{n}"><w:abstractNumId w:val="{n}"/></w:num>' for n in [1, *ordered])
            + "</w:numbering>")


def write_docx(target):
    converter = Converter()
    # Only the body: the head holds the title and the CSS.
    converter.feed(SOURCE.read_text(encoding="utf-8").split("<body>", 1)[1])
    document = (f'<w:document xmlns:w="{W}"><w:body>' + "".join(converter.body)
                + '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
                '<w:pgMar w:top="851" w:right="851" w:bottom="851" w:left="851" w:header="400" w:footer="400" w:gutter="0"/>'
                "</w:sectPr></w:body></w:document>")
    main = "application/vnd.openxmlformats-officedocument.wordprocessingml"
    office = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    package = "http://schemas.openxmlformats.org/package/2006"
    files = {
        "[Content_Types].xml": f'<Types xmlns="{package}/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        f'<Override PartName="/word/document.xml" ContentType="{main}.document.main+xml"/>'
        f'<Override PartName="/word/styles.xml" ContentType="{main}.styles+xml"/>'
        f'<Override PartName="/word/numbering.xml" ContentType="{main}.numbering+xml"/></Types>',
        "_rels/.rels": f'<Relationships xmlns="{package}/relationships">'
        f'<Relationship Id="r1" Type="{office}/officeDocument" Target="word/document.xml"/></Relationships>',
        "word/_rels/document.xml.rels": f'<Relationships xmlns="{package}/relationships">'
        f'<Relationship Id="r1" Type="{office}/styles" Target="styles.xml"/>'
        f'<Relationship Id="r2" Type="{office}/numbering" Target="numbering.xml"/></Relationships>',
        "word/document.xml": document,
        "word/styles.xml": styles(),
        "word/numbering.xml": numbering(converter.ordered),
    }
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, xml in files.items():
            archive.writestr(name, '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + xml)


def write_pdf(target):
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as profile:
        subprocess.run([CHROME, "--headless", "--disable-gpu", "--no-first-run", f"--user-data-dir={profile}",
                        "--no-pdf-header-footer", f"--print-to-pdf={target}", SOURCE.as_uri()],
                       check=True, capture_output=True, timeout=90)


def main():
    OUT.mkdir(exist_ok=True)
    word, pdf = OUT / f"{NAME}.docx", OUT / f"{NAME}.pdf"
    write_docx(word)
    write_pdf(pdf)
    print(f"{word}\n{pdf}")


if __name__ == "__main__":
    main()
