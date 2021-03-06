# Pure
# by Sindre Sorhus
# https://github.com/sindresorhus/pure
# MIT License

# For my own and others sanity
# git:
# %b => current branch
# %a => current action (rebase/merge)
# prompt:
# %F => color dict
# %f => reset color
# %~ => current path
# %* => time
# %n => username
# %m => shortname host
# %(?..) => prompt conditional - %(condition.true.false)
# terminal codes:
# \e7   => save cursor position
# \e[2A => move cursor 2 lines up
# \e[1G => go to position 1 in terminal
# \e8   => restore cursor position
# \e[K  => clears everything after the cursor on the current line
# \e[2K => clear everything on the current line


# turns seconds into human readable time
# 165392 => 1d 21h 56m 32s
# https://github.com/sindresorhus/pretty-time-zsh
prompt_pure_human_time_to_var() {
	local human=" " total_seconds=$1 var=$2
	local days=$(( total_seconds / 60 / 60 / 24 ))
	local hours=$(( total_seconds / 60 / 60 % 24 ))
	local minutes=$(( total_seconds / 60 % 60 ))
	local seconds=$(( total_seconds % 60 ))
	(( days > 0 )) && human+="${days}d "
	(( hours > 0 )) && human+="${hours}h "
	(( minutes > 0 )) && human+="${minutes}m "
	human+="${seconds}s"

	# store human readable time in variable as specified by caller
	typeset -g "${var}"="${human}"
}

# stores (into prompt_pure_cmd_exec_time) the exec time of the last command if set threshold was exceeded
prompt_pure_check_cmd_exec_time() {
	integer elapsed
	(( elapsed = EPOCHSECONDS - ${prompt_pure_cmd_timestamp:-$EPOCHSECONDS} ))
	prompt_pure_cmd_exec_time=
	(( elapsed > ${PURE_CMD_MAX_EXEC_TIME:=5} )) && {
		prompt_pure_human_time_to_var $elapsed "prompt_pure_cmd_exec_time"
	}
}

prompt_pure_clear_screen() {
	# enable output to terminal
	zle -I
	# clear screen and move cursor to (0, 0)
	print -n '\e[2J\e[0;0H'
	# print preprompt
	prompt_pure_preprompt_render precmd
}

prompt_pure_check_git_arrows() {
	# reset git arrows
	prompt_pure_git_arrows=

	# check if there is an upstream configured for this branch
	command git rev-parse --abbrev-ref @'{u}' &>/dev/null || return

	local arrow_status
	# check git left and right arrow_status
	arrow_status="$(command git rev-list --left-right --count HEAD...@'{u}' 2>/dev/null)"
	# exit if the command failed
	(( !$? )) || return

	# left and right are tab-separated, split on tab and store as array
	arrow_status=(${(ps:\t:)arrow_status})
	local arrows left=${arrow_status[1]} right=${arrow_status[2]}

	(( ${right:-0} > 0 )) && arrows+="${PURE_GIT_DOWN_ARROW:-⇣}"
	(( ${left:-0} > 0 )) && arrows+="${PURE_GIT_UP_ARROW:-⇡}"

	[[ -n $arrows ]] && prompt_pure_git_arrows=" ${arrows}"
}

prompt_pure_set_title() {
	# emacs terminal does not support settings the title
	(( ${+EMACS} )) && return

	# tell the terminal we are setting the title
	print -n '\e]0;'
	# show hostname if connected through ssh
	[[ -n $SSH_CONNECTION ]] && print -Pn '(%m) '
	case $1 in
		expand-prompt)
			print -Pn $2;;
		ignore-escape)
			print -rn $2;;
	esac
	# end set title
	print -n '\a'
}

prompt_pure_preexec() {
	# attempt to detect and prevent prompt_pure_async_git_fetch from interfering with user initiated git or hub fetch
	[[ $2 =~ (git|hub)\ .*(pull|fetch) ]] && async_flush_jobs 'prompt_pure'

	prompt_pure_cmd_timestamp=$EPOCHSECONDS

	# shows the current dir and executed command in the title while a process is active
	prompt_pure_set_title 'ignore-escape' "$PWD:t: $2"
}

# string length ignoring ansi escapes
prompt_pure_string_length_to_var() {
	local str=$1 var=$2 length
	# perform expansion on str and check length
	length=$(( ${#${(S%%)str//(\%([KF1]|)\{*\}|\%[Bbkf])}} ))

	# store string length in variable as specified by caller
	typeset -g "${var}"="${length}"
}


prompt_pure_short_pwd() {

    local short full part cur
    local first
    local -a split    # the array we loop over

    split=(${(s:/:)${(Q)${(D)1:-$PWD}}})

    if [[ $split == "" ]]; then
        print "/"
        return 0
    fi

    if [[ $split[1] = \~* ]]; then
        first=$split[1]
        full=$~split[1]
        shift split
    fi

    if (( $#split > 0 )); then
        part=/
    fi

    for cur ($split[1,-2]) {
            while {
                part+=$cur[1]
                cur=$cur[2,-1]
                local -a glob
                glob=( $full/$part*(-/N) )
                # continue adding if more than one directory matches or
                # the current string is . or ..
                # but stop if there are no more characters to add
                (( $#glob > 1 )) || [[ $part == (.|..) ]] && (( $#cur > 0 ))
            } { # this is a do-while loop
            }
                  full+=$part$cur
                  short+=$part
                  part=/
        }
        print "$first$short$part$split[-1]"
        return 0
}

prompt_pure_preprompt_render() {
	# set color for git branch/dirty status, change color if dirty checking has been delayed
	local git_color=242
	[[ -n ${prompt_pure_git_last_dirty_check_timestamp+x} ]] && git_color=red


  local jobs
  local prompt_mean_jobs
  unset jobs
  for a (${(k)jobstates}) {
          j=$jobstates[$a];i="${${(@s,:,)j}[2]}"
          jobs+=($a${i//[^+-]/})
      }

  case ${KEYMAP} in
      (vicmd)      VI_MODE="%F{blue}-- NORMAL --" ;;
      (main|viins) VI_MODE="%F{2}-- INSERT --" ;;
      (*)          VI_MODE="%F{2}-- INSERT --" ;;
  esac

  prompt_pure_jobs=""
  [[ -n $jobs ]] && prompt_pure_jobs="%F{242}["${(j:,:)jobs}"] "

  # construct pre prompt starting with jobs
  local preprompt="$prompt_pure_jobs"
  # tmux status
  preprompt+="%F{yellow}$prompt_pure_tmux"
  # exec time
  preprompt+="%F{magenta}${prompt_pure_cmd_exec_time}%f"
  # pwd
  preprompt+=" %F{blue}`prompt_pure_short_pwd` "
  # prompt symbol
  preprompt+="%B%F{1}❯%(?.%F{3}.%B%F{red})❯%(?.%F{2}.%B%F{red})❯%f%b "
	# prompt turns red if the previous command didn't exit with 0
	PROMPT=$preprompt


	# vi mode
	local postprompt="$VI_MODE"
	# git info
	postprompt+="%F{cyan}${vcs_info_msg_0_}${prompt_pure_git_dirty}%f"
	# git pull/push arrows
	postprompt+="%F{magenta}${prompt_pure_git_arrows}%f"
  # lambda host
  postprompt+=" %F{yellow}λ $prompt_pure_host"

  # render rprompt
  RPROMPT=$postprompt

  zle && zle .reset-prompt
}

prompt_pure_precmd() {

	# check exec time and store it in a variable
	prompt_pure_check_cmd_exec_time

	# by making sure that prompt_pure_cmd_timestamp is defined here the async functions are prevented from interfering
	# with the initial preprompt rendering
	prompt_pure_cmd_timestamp=

	# check for git arrows
	prompt_pure_check_git_arrows

	# shows the full path in the title
	prompt_pure_set_title 'expand-prompt' '%~'

	# get vcs info
	vcs_info

	# preform async git dirty check and fetch
	prompt_pure_async_tasks

	# print the preprompt
	prompt_pure_preprompt_render "precmd"

	# remove the prompt_pure_cmd_timestamp, indicating that precmd has completed
	unset prompt_pure_cmd_timestamp
}

# fastest possible way to check if repo is dirty
prompt_pure_async_git_dirty() {
	local untracked_dirty=$1; shift

	# use cd -q to avoid side effects of changing directory, e.g. chpwd hooks
	builtin cd -q "$*"

	if [[ "$untracked_dirty" == "0" ]]; then
		command git diff --no-ext-diff --quiet --exit-code
	else
		test -z "$(command git status --porcelain --ignore-submodules -unormal)"
	fi

	(( $? )) && echo "*"
}

prompt_pure_async_git_fetch() {
	# use cd -q to avoid side effects of changing directory, e.g. chpwd hooks
	builtin cd -q "$*"

	# set GIT_TERMINAL_PROMPT=0 to disable auth prompting for git fetch (git 2.3+)
	GIT_TERMINAL_PROMPT=0 command git -c gc.auto=0 fetch
}

prompt_pure_async_tasks() {
	# initialize async worker
	((!${prompt_pure_async_init:-0})) && {
		async_start_worker "prompt_pure" -u -n
		async_register_callback "prompt_pure" prompt_pure_async_callback
		prompt_pure_async_init=1
	}

	# store working_tree without the "x" prefix
	local working_tree="${vcs_info_msg_1_#x}"
  local newdir=false

	# check if the working tree changed (prompt_pure_current_working_tree is prefixed by "x")
	if [[ ${prompt_pure_current_working_tree#x} != $working_tree ]]; then
		# stop any running async jobs
		async_flush_jobs "prompt_pure"

		# reset git preprompt variables, switching working tree
		unset prompt_pure_git_dirty
    prompt_pure_git_last_dirty_check_timestamp=$EPOCHSECONDS
    newdir=true

		# set the new working tree and prefix with "x" to prevent the creation of a named path by AUTO_NAME_DIRS
		prompt_pure_current_working_tree="x${working_tree}"
	fi

	# only perform tasks inside git working tree
	[[ -n $working_tree ]] || return

	# do not preform git fetch if it is disabled or working_tree == HOME
	if (( ${PURE_GIT_PULL:-1} )) && [[ $working_tree != $HOME ]]; then
		# tell worker to do a git fetch
		async_job "prompt_pure" prompt_pure_async_git_fetch "${working_tree}"
	fi

	# if dirty checking is sufficiently fast, tell worker to check it again, or wait for timeout
	integer time_since_last_dirty_check=$(( EPOCHSECONDS - ${prompt_pure_git_last_dirty_check_timestamp:-0} ))
	if [[ "$newdir" = true || $time_since_last_dirty_check > ${PURE_GIT_DELAY_DIRTY_CHECK:-1800} ]]; then
		# check check if there is anything to pull
		async_job "prompt_pure" prompt_pure_async_git_dirty "${PURE_GIT_UNTRACKED_DIRTY:-1}" "${working_tree}"
	fi
}

prompt_pure_async_callback() {
	local job=$1
	local output=$3
	local exec_time=$4

	case "${job}" in
		prompt_pure_async_git_dirty)
			prompt_pure_git_dirty=$output
			prompt_pure_preprompt_render

			# When prompt_pure_git_last_dirty_check_timestamp is set, the git info is displayed in a different color.
			# To distinguish between a "fresh" and a "cached" result, the preprompt is rendered before setting this
			# variable. Thus, only upon next rendering of the preprompt will the result appear in a different color.
			(( $exec_time < 2 )) && unset prompt_pure_git_last_dirty_check_timestamp
			;;
		prompt_pure_async_git_fetch)
			prompt_pure_check_git_arrows
			prompt_pure_preprompt_render
			;;
	esac
}

prompt_pure_setup() {
	# prevent percentage showing up
	# if output doesn't end with a newline
	export PROMPT_EOL_MARK=''

	prompt_opts=(subst percent)

	zmodload zsh/datetime
	zmodload zsh/zle
	zmodload zsh/parameter

	autoload -Uz add-zsh-hook
	autoload -Uz vcs_info
	autoload -Uz async && async

	add-zsh-hook precmd prompt_pure_precmd
	add-zsh-hook preexec prompt_pure_preexec

	zstyle ':vcs_info:*' enable git
	zstyle ':vcs_info:*' use-simple true
	# only export two msg variables from vcs_info
	zstyle ':vcs_info:*' max-exports 2
	# vcs_info_msg_0_ = ' %b' (for branch)
	# vcs_info_msg_1_ = 'x%R' git top level (%R), x-prefix prevents creation of a named path (AUTO_NAME_DIRS)
	zstyle ':vcs_info:git*' formats ' %b' 'x%R'
	zstyle ':vcs_info:git*' actionformats ' %b|%a' 'x%R'

	# if the user has not registered a custom zle widget for clear-screen,
	# override the builtin one so that the preprompt is displayed correctly when
	# ^L is issued.
	if [[ $widgets[clear-screen] == 'builtin' ]]; then
		zle -N clear-screen prompt_pure_clear_screen
	fi

  prompt_pure_host="%F{cyan}%m%f"

  [[ "$TMUX" != '' ]] && prompt_pure_tmux="t"
}

function zle-line-init zle-keymap-select {
		prompt_pure_preprompt_render
    zle reset-prompt
}

zle -N zle-line-init
zle -N zle-keymap-select

prompt_pure_setup "$@"
