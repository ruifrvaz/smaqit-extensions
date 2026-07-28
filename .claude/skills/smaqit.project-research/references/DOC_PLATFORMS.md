---
version: "1.0.0"
---

# Platform-Aware URL Discovery Pattern Catalogue

This file defines the full set of URL patterns used by `smaqit.project-research` (Step 3) to discover documentation for tools and libraries not found via GitHub search alone.

Apply these patterns in cascade order: **GitHub → Agent Knowledge → Best-Guess Patterns → GitHub Wiki → Unknown**. Stop at the first strategy that yields a reachable URL.

---

## 1. GitHub (primary)

Use these tools first for any tool or library:

- `github_repo` — find the canonical repository; prefer the `homepage` URL if set (often points to official docs)
- `github_text_search` — locate GitHub Pages docs (`*.github.io`) or `docs/` subdirectory links
- GitHub Pages default URL: `https://{owner}.github.io/{repo}/`

---

## 2. Agent Knowledge (direct)

If the tool has a well-known canonical docs URL, use it directly without fetching:

| Tool / Platform | Canonical Docs URL |
|---|---|
| Docker | https://docs.docker.com |
| Python | https://docs.python.org/3 |
| Go | https://go.dev/doc |
| Node.js | https://nodejs.org/en/docs |
| React | https://react.dev |
| TypeScript | https://www.typescriptlang.org/docs |
| Rust | https://doc.rust-lang.org |
| Kubernetes | https://kubernetes.io/docs |
| PostgreSQL | https://www.postgresql.org/docs |
| Redis | https://redis.io/docs |
| Git | https://git-scm.com/doc |
| GitHub Actions | https://docs.github.com/en/actions |
| AWS | https://docs.aws.amazon.com |
| Azure | https://learn.microsoft.com/en-us/azure |
| GCP | https://cloud.google.com/docs |

This list is non-exhaustive. Use agent knowledge for any tool whose canonical docs URL is well-known before attempting best-guess patterns.

---

## 3. Best-Guess URL Patterns (fallback)

Try these patterns in order, using `fetch_webpage` to verify reachability. Stop at the first pattern that returns a live page.

### 3a. Official docs subdomain

```
https://docs.{tool-name}.io
https://docs.{tool-name}.com
https://docs.{tool-name}.dev
```

**Examples:**
- `https://docs.stripe.com`
- `https://docs.fastapi.tiangolo.com`
- `https://docs.pydantic.dev`

### 3b. ReadTheDocs

```
https://{tool-name}.readthedocs.io
https://{tool-name}.readthedocs.io/en/stable
https://{tool-name}.readthedocs.io/en/latest
```

**Examples:**
- `https://requests.readthedocs.io/en/stable`
- `https://celery.readthedocs.io/en/stable`

### 3c. Go module docs (`pkg.go.dev`)

Use the **full module path** from `go.mod` (e.g., `github.com/gin-gonic/gin`):

```
https://pkg.go.dev/{module-path}
https://pkg.go.dev/{module-path}#section-documentation
```

**Examples:**
- `https://pkg.go.dev/github.com/gin-gonic/gin`
- `https://pkg.go.dev/golang.org/x/net/http2`

### 3d. npm packages (`npmjs.com`)

Use the **exact package name** from `package.json` dependencies (including scoped packages like `@org/pkg`):

```
https://www.npmjs.com/package/{package-name}
```

**Examples:**
- `https://www.npmjs.com/package/express`
- `https://www.npmjs.com/package/@nestjs/core`

For scoped packages, the README tab on npmjs.com often links to external docs.

### 3e. Python packages (`pypi.org`)

Use the **exact distribution name** from `requirements.txt` or `pyproject.toml`:

```
https://pypi.org/project/{package-name}
```

**Examples:**
- `https://pypi.org/project/django`
- `https://pypi.org/project/httpx`

The PyPI project page includes a "Project Links" section that often points to canonical docs. Extract that URL if present.

### 3f. Ruby gems (`rubygems.org`)

Use the **gem name** from `Gemfile`:

```
https://rubygems.org/gems/{gem-name}
```

**Examples:**
- `https://rubygems.org/gems/rails`
- `https://rubygems.org/gems/sidekiq`

### 3g. Rust crates (`docs.rs`)

Use the **crate name** from `Cargo.toml`:

```
https://docs.rs/{crate-name}
https://crates.io/crates/{crate-name}
```

**Examples:**
- `https://docs.rs/tokio`
- `https://docs.rs/serde`

### 3h. NuGet packages (`.NET`)

Use the **package name** from `*.csproj` or `packages.config`:

```
https://www.nuget.org/packages/{package-name}
https://learn.microsoft.com/en-us/dotnet/api/{namespace}
```

**Examples:**
- `https://www.nuget.org/packages/Newtonsoft.Json`
- `https://learn.microsoft.com/en-us/dotnet/api/system.net.http`

### 3i. Maven packages (Java)

Use the **`groupId:artifactId`** from `pom.xml`:

```
https://mvnrepository.com/artifact/{groupId}/{artifactId}
https://javadoc.io/doc/{groupId}/{artifactId}
```

**Examples:**
- `https://mvnrepository.com/artifact/org.springframework.boot/spring-boot-starter`
- `https://javadoc.io/doc/com.google.guava/guava`

---

## 4. GitHub Wiki (last resort)

If all patterns above fail, try the GitHub wiki for the tool's repository:

```
https://github.com/{owner}/{repo}/wiki
```

Only use this if the repository was already located in Step 1 (GitHub search). Do not guess `{owner}/{repo}` — use the confirmed repo path.

---

## 5. Unknown (fallback)

If **all** strategies above fail:

- Set the tool's URL column to `Unknown` in the research map
- Do not omit the tool from the map
- Do not block execution — continue with remaining tools

---

## Notes

- **Scope:** Public documentation only. Do not attempt authenticated endpoints, private wikis, Confluence, GitLab self-hosted, or internal portals.
- **Rate limiting:** If `fetch_webpage` returns 429 or is unavailable, skip pattern verification and mark as `Unknown` rather than blocking.
- **Canonical vs package registry:** Prefer the canonical docs site (3a, 3b) over the package registry page (3d, 3e) when both exist, as registry pages are often less detailed.
- **Version pinning:** When using versioned doc URLs (readthedocs `en/stable`, `en/latest`), prefer `stable` for production projects, `latest` for pre-release or dev environments.
