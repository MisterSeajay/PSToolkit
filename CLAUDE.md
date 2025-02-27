# PSToolkit Guidelines

## Commands

* Import module: `Import-Module ./PSToolkit.psd1 -Force`
* Run PowerShell linter: `Invoke-ScriptAnalyzer -Path ./`
* Create new function: `New-Item -Path ./Public/Function-Name.ps1`
* Build module: `.\Scripts\Build-Module.ps1 -OutputPath "C:\path\to\output" -Verbose`

## Code Style

### PowerShell

* Use `Set-StrictMode -Version 2` in scripts
* Function naming:
  * Public functions: Follow Verb-Noun format (PascalCase) using only approved PowerShell verbs (Get-Verb)
  * Internal helper functions: Use camelCase (e.g., `getConfig`, `parseData`)
* Variable naming: Use PascalCase
* Always use [CmdletBinding()] for advanced functions
* Include comment-based help with Synopsis, Description, Parameters, Examples, Notes
* Add parameter validation with [ValidateScript] and [Parameter(Mandatory)]
* Use script scope prefix ($script:) for script-level variables
* Always provide parameter types (e.g., [string], [int])
* Indent with 4 spaces, not tabs
* Error handling: Use try/catch blocks for critical operations
* Use PowerShell custom objects with ordered properties when returning multiple values

### Markdown

* Include blank line before and after lists
* Include blank line after headings
* Use ATX-style headings with space after # (e.g., `# Heading`)
* Use asterisks for unordered lists
* End files with a single blank line
