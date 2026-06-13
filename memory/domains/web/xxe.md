# XML External Entity (XXE)

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

XXE ndodh kur parser-at XML procesojne external entity references nga XML i furnizuar nga perdoruesi.

### Skenare te prekshem

**Input XML direkt:**
- SOAP APIs.
- XML-RPC.
- Upload skedaresh XML.
- Parsim konfigurimesh.
- RSS / Atom feeds.

**Indirekte:**
- JSON / format te tjere te konvertuara ne XML ne server.
- Dokumente Office (DOCX, XLSX, PPTX jane ZIP me XML).
- SVG (i bazuar ne XML).
- SAML assertions.
- PDF me XFA forms.

### Parandalimi sipas gjuhes / parser-it

**Java:**

```java
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
dbf.setFeature("http://xml.org/sax/features/external-general-entities", false);
dbf.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
dbf.setExpandEntityReferences(false);
```

**Python (lxml):**

```python
from lxml import etree
parser = etree.XMLParser(resolve_entities=False, no_network=True)
# Ose perdor defusedxml
```

**PHP:**

```php
libxml_disable_entity_loader(true);
// Ose XMLReader me settings te duhura
```

**Node.js:**

```javascript
// Perdor biblioteka qe c'aktivizojne DTD by default
// Per libxmljs: { noent: false, dtdload: false }
```

**.NET:**

```csharp
XmlReaderSettings settings = new XmlReaderSettings();
settings.DtdProcessing = DtdProcessing.Prohibit;
settings.XmlResolver = null;
```

### Lista e parandalimit XXE

- [ ] C'aktivizo DTD processing krejtesisht nese mundet.
- [ ] C'aktivizo external entity resolution.
- [ ] C'aktivizo external DTD loading.
- [ ] C'aktivizo XInclude processing.
- [ ] Perdor versionet me te fundit te parser-ave XML.
- [ ] Valido / sanitize XML para parsing nese duhet DTD.
- [ ] Konsidero JSON ne vend te XML ku mundet.

---

## English

XXE vulnerabilities occur when XML parsers process external entity references in user-supplied XML.

### Vulnerable scenarios

**Direct XML input:**
- SOAP APIs.
- XML-RPC.
- XML file uploads.
- Configuration file parsing.
- RSS / Atom feed processing.

**Indirect:**
- JSON / other format converted to XML server-side.
- Office documents (DOCX, XLSX, PPTX are ZIP with XML).
- SVG (XML-based).
- SAML assertions.
- PDF with XFA forms.

### Prevention by language / parser

**Java:**

```java
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
dbf.setFeature("http://xml.org/sax/features/external-general-entities", false);
dbf.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
dbf.setExpandEntityReferences(false);
```

**Python (lxml):**

```python
from lxml import etree
parser = etree.XMLParser(resolve_entities=False, no_network=True)
# Or use defusedxml
```

**PHP:**

```php
libxml_disable_entity_loader(true);
// Or XMLReader with proper settings
```

**Node.js:**

```javascript
// Use libraries that disable DTD processing by default
// For libxmljs: { noent: false, dtdload: false }
```

**.NET:**

```csharp
XmlReaderSettings settings = new XmlReaderSettings();
settings.DtdProcessing = DtdProcessing.Prohibit;
settings.XmlResolver = null;
```

### XXE prevention checklist

- [ ] Disable DTD processing entirely if possible.
- [ ] Disable external entity resolution.
- [ ] Disable external DTD loading.
- [ ] Disable XInclude processing.
- [ ] Use latest patched XML parser versions.
- [ ] Validate / sanitize XML before parsing if DTD is needed.
- [ ] Consider JSON instead of XML where possible.
