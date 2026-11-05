#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

normalize() {
  tr '\n' ' ' | tr -s '[:space:]' ' '
}

expect() {
  local text=$1 phrase=$2 context=$3
  [[ "$text" == *"$phrase"* ]] || { printf 'Missing %s: %s\n' "$context" "$phrase" >&2; return 1; }
}

expect_order() {
  local text=$1 context=$2
  shift 2
  local pattern='*'
  for phrase in "$@"; do pattern+="$phrase*"; done
  [[ "$text" == $pattern ]] || { printf 'Incorrect reading order: %s\n' "$context" >&2; return 1; }
}

check_pdf() {
  local pdf=$1 language=$2 pages='' metadata urls mode text normalized
  metadata=$(pdfinfo "$pdf")
  while IFS= read -r line; do
    if [[ $line == Pages:* ]]; then pages=${line#Pages:}; pages=${pages//[[:space:]]/}; fi
  done <<< "$metadata"
  [[ $pages == 1 ]] || { printf '%s must be one page (found %s)\n' "$pdf" "${pages:-unknown}" >&2; return 1; }

  urls=$(pdfinfo -url "$pdf")
  for url in 'mailto:franco.rguadalupe@gmail.com' 'https://guada-franco.pages.dev/' 'https://linkedin.com/in/guadalupe-franco' 'https://github.com/gdpe-franco'; do
    expect "$urls" "$url" "$pdf hyperlink"
  done
  for slug in ai-coding-agent-pipeline book-management-system; do
    if [[ $language == en ]]; then
      expect "$urls" "https://guada-franco.pages.dev/projects/$slug" "$pdf project link"
    else
      expect "$urls" "https://guada-franco.pages.dev/es/projects/$slug" "$pdf project link"
    fi
  done

  for mode in normal layout; do
    if [[ $mode == layout ]]; then
      text=$(pdftotext -layout -enc UTF-8 "$pdf" - | normalize)
    else
      text=$(pdftotext -enc UTF-8 "$pdf" - | normalize)
    fi
    expect "$text" 'Guadalupe Franco' "$pdf/$mode name"
    expect "$text" 'Querétaro, México' "$pdf/$mode Unicode extraction"
    expect "$text" 'Mienvío' "$pdf/$mode Unicode extraction"
    expect "$text" 'SAML 2.0, JWT, RBAC, MCP' "$pdf/$mode punctuation and skills"
    [[ "$text" != *$'\uFFFD'* ]] || { printf 'Unicode replacement character in %s/%s\n' "$pdf" "$mode" >&2; return 1; }

    if [[ $language == en ]]; then
      expect "$text" 'Full-Stack Software Engineer' "$pdf/$mode title"
      expect "$text" 'MedTrainer' "$pdf/$mode employer"
      expect "$text" 'Full-Stack Developer' "$pdf/$mode job title"
      expect "$text" 'Web Developer Intern' "$pdf/$mode job title"
      expect "$text" 'PHP (Laravel, Symfony), Node.js (NestJS), Python (FastAPI, Pydantic), Go' "$pdf/$mode skill grouping"
      expect "$text" 'MCP integrations to internal APIs' "$pdf/$mode MCP bullet"
      if [[ $mode == normal ]]; then
        expect "$text" 'questions beyond course recommendations' "$pdf/$mode MCP bullet"
        expect "$text" 'solutions focused on customer needs' "$pdf/$mode Mienvío bullet"
      else
        expect "$text" 'enabling responses to questions' "$pdf/$mode MCP bullet"
      fi
      expect_order "$text" "$pdf/$mode sections" 'Experience' 'Projects' 'Education'
      expect_order "$text" "$pdf/$mode employment dates" 'Sep. 2025 – Jul. 2026' 'Aug. 2023 – Sep. 2025' '2022 – 2023'
      [[ "$text" != *'customerfocused'* ]] || { printf 'Concatenated customer-focused wording in %s/%s\n' "$pdf" "$mode" >&2; return 1; }
    else
      expect "$text" 'Ingeniera de Software Full-Stack' "$pdf/$mode title"
      expect "$text" 'MedTrainer' "$pdf/$mode employer"
      expect "$text" 'Desarrolladora Full-Stack' "$pdf/$mode job title"
      expect "$text" 'Desarrolladora Web (Becaria)' "$pdf/$mode job title"
      expect "$text" 'Español (Nativo), Inglés (C1), Portugués (A1)' "$pdf/$mode languages and punctuation"
      expect "$text" 'integraciones MCP con APIs internas' "$pdf/$mode MCP bullet"
      expect "$text" 'más allá de las recomendaciones de cursos' "$pdf/$mode MCP bullet"
      expect_order "$text" "$pdf/$mode sections" 'Experiencia' 'Proyectos destacados' 'Formación académica'
      expect_order "$text" "$pdf/$mode employment dates" 'Sep. 2025 – Jul. 2026' 'Ago. 2023 – Sep. 2025' '2022 – 2023'
    fi
  done
}

check_pdf cv.pdf en
check_pdf cv-es.pdf es
printf 'Extraction checks passed for both one-page CVs (normal and layout text).\n'
