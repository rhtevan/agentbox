# bash completion for goose-sandbox (gs)

_goose_sandbox() {
    local cur prev words cword
    _get_comp_words_by_ref -n : cur prev words cword

    local commands="run session list delete status help"
    local global_opts="-h --help"

    local run_opts="--name -n --provider --model --text -t --instructions -i --system --no-session --no-keep --max-turns --max-tool-repetitions --with-extension --with-builtin --debug -h --help"
    local session_opts="--name -n --provider --model --system --history --max-turns --max-tool-repetitions --with-extension --with-builtin --debug -h --help"
    local session_subcommands="resume"

    # Top-level command completion
    if [ "$cword" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$commands $global_opts" -- "$cur") )
        return
    fi

    local cmd="${words[1]}"

    case "$cmd" in
        run)
            case "$prev" in
                --provider)
                    local providers
                    providers=$(grep -oP '^\s+\K\S+(?=:)' ~/.config/goose/config.yaml 2>/dev/null | grep '^custom_' || echo "")
                    COMPREPLY=( $(compgen -W "$providers" -- "$cur") )
                    return
                    ;;
                --model|-n|--name|--text|-t|--instructions|-i|--system|--max-turns|--max-tool-repetitions)
                    return
                    ;;
            esac
            COMPREPLY=( $(compgen -W "$run_opts" -- "$cur") )
            ;;
        session)
            if [ "$cword" -eq 2 ]; then
                COMPREPLY=( $(compgen -W "$session_subcommands $session_opts" -- "$cur") )
                return
            fi
            local subcmd="${words[2]}"
            if [ "$subcmd" = "resume" ]; then
                # Complete with running sandbox names
                if [ "$cword" -eq 3 ]; then
                    local sandboxes
                    sandboxes=$(openshell sandbox list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk 'NR>1 && $NF=="Ready" {print $1}')
                    COMPREPLY=( $(compgen -W "$sandboxes" -- "$cur") )
                    return
                fi
            fi
            case "$prev" in
                --provider)
                    local providers
                    providers=$(grep -oP '^\s+\K\S+(?=:)' ~/.config/goose/config.yaml 2>/dev/null | grep '^custom_' || echo "")
                    COMPREPLY=( $(compgen -W "$providers" -- "$cur") )
                    return
                    ;;
                --model|-n|--name|--system|--max-turns|--max-tool-repetitions)
                    return
                    ;;
            esac
            COMPREPLY=( $(compgen -W "$session_opts" -- "$cur") )
            ;;
        delete)
            if [ "$cword" -eq 2 ]; then
                local sandboxes
                sandboxes=$(openshell sandbox list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk 'NR>1 {print $1}')
                COMPREPLY=( $(compgen -W "$sandboxes" -- "$cur") )
            fi
            ;;
        list|status|help)
            ;;
    esac
}

complete -F _goose_sandbox goose-sandbox
complete -F _goose_sandbox gs
