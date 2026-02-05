" Vim syntax file
" Language:    SSNS ETL Script
" Maintainer:  SSNS
" Description: Syntax highlighting for .ssns ETL script files

if exists("b:current_syntax")
  finish
endif

" Load SQL syntax as base
runtime! syntax/sql.vim
unlet! b:current_syntax

" ETL Directive Keywords
syn match ssnsDirective /--@block\s\+\S\+/ contains=ssnsDirectiveKeyword,ssnsBlockName
syn match ssnsDirective /--@lua\s\+\S\+/ contains=ssnsDirectiveKeyword,ssnsBlockName
syn match ssnsDirective /--@server\s\+\S\+/ contains=ssnsDirectiveKeyword,ssnsServerName
syn match ssnsDirective /--@database\s\+\S\+/ contains=ssnsDirectiveKeyword,ssnsDatabaseName
syn match ssnsDirective /--@description\s\+.*$/ contains=ssnsDirectiveKeyword,ssnsDescription
syn match ssnsDirective /--@input\s\+\S\+/ contains=ssnsDirectiveKeyword,ssnsInputRef
syn match ssnsDirective /--@output\s\+\S\+/ contains=ssnsDirectiveKeyword,ssnsOutputType
syn match ssnsDirective /--@mode\s\+\S\+/ contains=ssnsDirectiveKeyword,ssnsMode
syn match ssnsDirective /--@target\s\+\S\+/ contains=ssnsDirectiveKeyword,ssnsTarget
syn match ssnsDirective /--@skip_on_empty\>/ contains=ssnsDirectiveKeyword
syn match ssnsDirective /--@continue_on_error\>/ contains=ssnsDirectiveKeyword
syn match ssnsDirective /--@timeout\s\+\d\+/ contains=ssnsDirectiveKeyword,ssnsNumber
syn match ssnsDirective /--@var\s\+\S\+\s*=\s*.*$/ contains=ssnsDirectiveKeyword,ssnsVarName,ssnsVarValue

" Directive components
syn match ssnsDirectiveKeyword /--@\(block\|lua\|server\|database\|description\|input\|output\|mode\|target\|skip_on_empty\|continue_on_error\|timeout\|var\)/ contained
syn match ssnsBlockName /\s\+\zs\S\+/ contained
syn match ssnsServerName /\s\+\zs\S\+/ contained
syn match ssnsDatabaseName /\s\+\zs\S\+/ contained
syn match ssnsDescription /\s\+\zs.*$/ contained
syn match ssnsInputRef /\s\+\zs\S\+/ contained
syn match ssnsOutputType /\s\+\zs\(sql\|data\)/ contained
syn match ssnsMode /\s\+\zs\(select\|insert\|upsert\|truncate_insert\|incremental\)/ contained
syn match ssnsTarget /\s\+\zs\S\+/ contained
syn match ssnsVarName /\s\+\zs\S\+\ze\s*=/ contained
syn match ssnsVarValue /=\s*\zs.*$/ contained
syn match ssnsNumber /\d\+/ contained

" @input placeholder in SQL
syn match ssnsInputPlaceholder /@input\>/

" Template variable substitution
syn match ssnsTemplateVar /{{[^}]\+}}/

" Highlighting - Use SSNS theme groups for consistent styling
hi def link ssnsDirectiveKeyword SsnsKeywordStatement
hi def link ssnsBlockName SsnsFunction
hi def link ssnsServerName SsnsSchema
hi def link ssnsDatabaseName SsnsDatabase
hi def link ssnsDescription SsnsComment
hi def link ssnsInputRef SsnsParameter
hi def link ssnsOutputType SsnsKeywordModifier
hi def link ssnsMode SsnsKeywordModifier
hi def link ssnsTarget SsnsTable
hi def link ssnsVarName SsnsColumn
hi def link ssnsVarValue SsnsString
hi def link ssnsNumber SsnsNumber
hi def link ssnsInputPlaceholder SsnsParameter
hi def link ssnsTemplateVar SsnsKeywordGlobalVariable

let b:current_syntax = "ssns"
