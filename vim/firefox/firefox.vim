" This
"
"
"
"
"

" Build related variables
let s:build_cmd = "mach"
let s:build_args = "build"

" Run related variables
let s:run_cmd = "mach"

" Run related variables
let s:debug_cmd = "gdb"
let s:debug_args = "debug"

" This config how we make sure it is root directory
let s:root_folder_criteria = ['mach', 'GNUmakefile']

" Just a utility function
function! s:ListToPath(list)
  return '/' . join(a:list, '/') . '/'
endfunction

function! s:BuildArgs(args)
  return ' ' . join(a:args, ' ')
endfunction

let s:browsertest_criteria = ['browser.ini']
function! s:IsBrowsertest()
  for item in s:browsertest_criteria
    let find = findfile(item, s:full_dir_path)
    if find == ''
      return 0
    endif
  endfor

  return 1
endfunction

let s:mochitest_criteria = ['mochitest.ini']
function! s:IsMochitest()
  for item in s:mochitest_criteria
    let find = findfile(item, s:full_dir_path)
    if find == ''
      return 0
    endif
  endfor

  return 1
endfunction

let s:xpcshelltest_criteria = ['xpcshell.ini']
function! s:IsXpcshelltest()
  for item in s:xpcshelltest_criteria
    let find = findfile(item, s:full_dir_path)
    if find == ''
      return 0
    endif
  endfor

  return 1
endfunction

" This function keeping going to parent folder until hit a folder
" with all 'root_folder_criteria' in it.
function! s:FindRootFolder()
  let path = split(expand('%:p'), '/')

  while path != []
    let search_folder = '/' . join(path, '/')
    for item in s:root_folder_criteria
      let find = findfile(item, search_folder)
      if find == ''
        break
      endif
    endfor

    if find != ''
      let s:root_dir_list = split(search_folder, '/')
      let s:root_dir_path = s:ListToPath(s:root_dir_list)
      break
    endif

    let path = path[:-2]
  endwhile
endfunction

let s:obj_dir_criteria = ['dist', 'build']
function! s:FindObjFolder()
  let dirs = globpath(s:root_dir_path, '*/', 0, 1)
  call filter(dirs, 'isdirectory(v:val)')

  for dir in dirs
    for item in s:obj_dir_criteria
      let find = finddir(item, dir)
      if find == ''
        break
      endif
    endfor

    if find != ''
      let s:obj_dir_list = split(dir, '/')
      let s:obj_dir_path = s:ListToPath(s:obj_dir_list)
      return
    endif
  endfor
endfunction

" Setup current folder, current file & root folder
function! s:InitScriptVariables()
  let current_path = split(expand('%:p'), '/')
  if current_path == []
    return
  endif

  " Get full path
  let s:full_dir_list = split(expand('%:p:h'), '/')
  let s:full_dir_path = s:ListToPath(s:full_dir_list)

  " Get the folder we call VIM
  let s:current_folder_list = split(expand("<sfile>:p:h"), '/')
  let s:current_folder_str = s:ListToPath(s:current_folder_list)

  " Get file name
  let s:file_str = current_path[-1]

  " Get root folder
  call s:FindRootFolder()
  let s:relative_path_list = s:full_dir_list[len(s:root_dir_list):]
  let s:relative_path_str = '.' . s:ListToPath(s:relative_path_list)
  echo s:relative_path_str

  call s:FindObjFolder()

  echo 'full folder :' . s:full_dir_path
  echo 'current folder :' . s:current_folder_str
  echo 'file :' . s:file_str
  echo 'root :' . s:root_dir_path
  echo 'obj :' . s:obj_dir_path

endfunction

let s:bps = []
function! s:FirefoxSetBP()
  let bp_line = line('.')
  let bp_file = expand('%:t')
  let target = bp_file . ":" . bp_line

  let idx = index(s:bps, target)
  if idx == 0
    let s:bps = s:bps[idx+1:-1]
  elseif idx > 0
    let s:bps = s:bps[0 :idx-1] + s:bps[idx+1:-1]
  else
    call add(s:bps, target)
  endif

  "Poor way to integrate with Bookmark"
  execute 'BookmarkToggle'
endfunction

function! s:GetBreakPoint()
  let pending_on_cmd = "set breakpoint pending on"
  let run_cmd = "run"
  let config = [pending_on_cmd] + s:bps + [run_cmd]
  let s:bp_data = join(config, "\n")
endfunction

function! s:RunOneQuickFixCmd(cmd)
  tabdo ccl
  tabnew
  execute "AsyncStop"
  execute "AsyncRun " . a:cmd
  quit
endfunction

function! s:FirefoxBuild()
  call s:InitScriptVariables()
  let args = s:BuildArgs(['build'])
  let cmd = s:root_dir_path . s:build_cmd . args
  call s:RunOneQuickFixCmd(cmd)
endfunction

function! s:FirefoxCustomRun4()
  call s:InitScriptVariables()

  let args = s:BuildArgs(['test', '--headless', s:relative_path_str . s:file_str])
  "let args = s:BuildArgs(['wpt', '--headless', s:relative_path_str . s:file_str])

  let cmd = s:root_dir_path . s:run_cmd . args
  echo "Run :" . cmd

  call s:RunOneQuickFixCmd(cmd)
endfunction

function! s:FirefoxCustomRun3()
  call s:InitScriptVariables()

  let args = s:BuildArgs(['test', '--headless', '--enable-fission', s:relative_path_str . s:file_str])

  let cmd = s:root_dir_path . s:run_cmd . args
  echo "Run :" . cmd

  call s:RunOneQuickFixCmd(cmd)
endfunction

function! s:FirefoxCustomRun2()
  call s:InitScriptVariables()

  let args = s:BuildArgs(['test', '--headless', '--run-until-failure', s:relative_path_str . s:file_str])

  let cmd = s:root_dir_path . s:run_cmd . args
  echo "Run :" . cmd

  call s:RunOneQuickFixCmd(cmd)
endfunction

function! s:FirefoxCustomRun1()
  call s:InitScriptVariables()

  let args = s:BuildArgs(['test', '--headless', '--enable-fission', '--enable-xorigin-tests', s:relative_path_str . s:file_str])

  let cmd = s:root_dir_path . s:run_cmd . args
  echo "Run :" . cmd

  call s:RunOneQuickFixCmd(cmd)
endfunction

function! s:FirefoxRun()
  call s:InitScriptVariables()

  if s:IsMochitest()
    let args = s:BuildArgs(['mochitest', s:relative_path_str . s:file_str])
  elseif s:IsBrowsertest()
    let args = s:BuildArgs(['mochitest', '-f', 'browser', s:relative_path_str . s:file_str])
  elseif s:IsXpcshelltest()
    let args = s:BuildArgs(['xpcshell-test', s:relative_path_str . s:file_str])
  else
    echo "Run firefox"
    let args = s:BuildArgs(['run'])
  endif

  let cmd = s:root_dir_path . s:run_cmd . args
  echo "Run :" . cmd

  call s:RunOneQuickFixCmd(cmd)
endfunction

function! s:WriteToTempFile(file, data)
  new
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  put=a:data
  execute 'w ' a:file
  q
endfunction

let s:bp_file = "/tmp/_firefox_bps"

function! s:FirefoxDebug()
  call s:InitScriptVariables()

  call s:GetBreakPoint()

  " Write to file so gdb can read it
  call s:WriteToTempFile(s:bp_file, s:bp_data)

  let firefox = s:obj_dir_path . 'dist/bin/firefox'
  let profile = s:obj_dir_path . 'tmp/profile-default'
  "let args = s:BuildArgs(['-ex', 'run', '-q', '--args', firefox, '-no-remote', '-profile', profile])
  let args = s:BuildArgs(['-x', s:bp_file, '-q', '--args', firefox, '-no-remote', '-profile', profile])
  echo s:debug_cmd . args
  execute '!' . s:debug_cmd . args
endfunction

function! s:OnExit()
  " Ensure bookmarks don't exist after closing VIM"
  execute 'BookmarkClear'
endfunction

" Configure mapping here
" Not yet support argment for build and run
command! -nargs=0 Fbuild call s:FirefoxBuild()
command! -nargs=0 Frun call s:FirefoxRun()
command! -nargs=0 Fdebug call s:FirefoxDebug()
command! -nargs=0 Fbp call s:FirefoxSetBP()
command! -nargs=0 Fc1 call s:FirefoxCustomRun1()
command! -nargs=0 Fc2 call s:FirefoxCustomRun2()
command! -nargs=0 Fc3 call s:FirefoxCustomRun3()
command! -nargs=0 Fc4 call s:FirefoxCustomRun4()

autocmd VimLeave * call s:OnExit()

if exists("g:EnableFirefoxBuildMapping")
  if g:EnableFirefoxBuildMapping == 1
    "F5 build coda
    map <F5> :Fbuild<CR>

    "F6 run
    map <F6> :Frun<CR>

    "F7 debug
    map <F7> :Fdebug<CR>

    "F8 set break point
    map <F8> :Fbp<CR>

    "F9 Custom run function
    map <F9> :Fc1<CR>

    "F10 Custom run function
    map <F10> :Fc2<CR>

    "F11 Custom run function
    map <F11> :Fc3<CR>

    "F12 Custom run function
    map <F12> :Fc4<CR>
  endif
endif
