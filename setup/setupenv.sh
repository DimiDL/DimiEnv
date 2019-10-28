#bin/sh

BeginSetup()
{
echo "Setup $1 ..."
}

EndSetup()
{
echo "OK\n"
}

# Basic tools
BeginSetup "terminator"
sudo apt-get install terminator
EndSetup

BeginSetup "git"
# sudo apt-get install git
git config --global user.email dlee@mozilla.com
git config user.name DimiDL

BeginSetup "vim"
VIM_RC_PATH="$HOME/.vim"
mkdir -p $VIM_RC_PATH

sudo apt-get install vim
git config --global core.editor vim
git config --global core.pager 'less -FRX'

if [ ! -e $VIM_RC_PATH ] ; then
#todo
#Plugin 'inkarkat/vim-ingo-library'
#Plugin 'inkarkat/vim-mark'

	cd $VIM_RC_PATH
	git clone https://github.com/DimiL/vim $VIM_RC_PATH

  BeginSetup "vim plugins"

	git submodule init
	git submodule update

	vim -c 'PluginInstall' -c 'qa!'
  BeginSetup "YouCompleteMe"
  YOUCOMPLETEME_PATH=$VIM_RC_PATH/bundle/YouCompleteMe
  sudo apt-get install cmake
  $YOUCOMPLETEME_PATH/install.py --clang-completer

fi

# Fuzzy Finder
BeginSetup "fuzzy finder"

FUZZY_FINDER_PATH="$HOME/.fzf"
if [ ! -e $FUZZY_FINDER_PATH ] ; then
	git clone --depth 1 https://github.com/junegunn/fzf.git $FUZZY_FINDER_PATH
	cd $FUZZY_FINDER_PATH
	./install
fi


BeginSetup "open ssh"
# sudo apt-get install openssh-server
# sudo service ssh restart

# Mozilla Build
# TODO : put gkey in mozbuild
# MAC mozconfig and Ubuntu mozconfig
BeginSetup "Mozilla Build"

BOOTSTRAP="https://hg.mozilla.org/mozilla-central/raw-file/default/python/mozboot/bin/bootstrap.py"
BOOTSTRAP_PATH="$HOME/Downloads/bootstrap.py"

#[ -e $BOOTSTRAP_PATH ] && rm $BOOTSTRAP_PATH
#wget $BOOTSTRAP -O ~/Downloads/bootstrap.py
#python ~/Downloads/bootstrap.py --vcs=git

FIREFOX_PROJECT_PATH="$HOME/Firefox"
FIREFOX_MOZBUILD_PATH="$HOME/.mozbuild"
mkdir -p $FIREFOX_PROJECT_PATH
mkdir -p $FIREFOX_MOZBUILD_PATH

# Install git-cinnabar
BeginSetup "git-cinnabar"
if [ ! -e $FIREFOX_MOZBUILD_PATH/git-cinnabar ] ; then
	git clone "https://github.com/glandium/git-cinnabar" $FIREFOX_MOZBUILD_PATH
fi

export PATH="$PATH:$FIREFOX_MOZBUILD_PATH/git-cinnabar"
#git cinnabar download

if [ ! -e $FIREFOX_PROJECT_PATH/gecko ] ; then
        mkdir -p $FIREFOX_PROJECT_PATH/gecko
	git clone hg::https://hg.mozilla.org/mozilla-unified $FIREFOX_PROJECT_PATH/gecko

	cd $FIREFOX_PROJECT_PATH/gecko
	git config fetch.prune true
	git remote add try hg::https://hg.mozilla.org/try
	git config remote.try.skipDefaultUpdate true
	git remote set-url --push try hg::ssh://hg.mozilla.org/try
	git config remote.try.push +HEAD:refs/heads/branches/default/tip
fi

# Install Arcanist
# https://moz-conduit.readthedocs.io/en/latest/arcanist-linux.html
sudo apt-get install php php-curl
MOZPHAB_PATH="$HOME/.mozbuild/arcanist"

if [ ! -e $MOZPHAB_PATH ] ; then
  cd ~/.mozbuild
  git clone https://github.com/phacility/arcanist.git
  git clone https://github.com/phacility/libphutil.git
fi

# Inall moz-phab
MOZPHAB_PATH="$HOME/.mozbuild/moz-phab"
if [ ! -e $MOZPHAB_PATH ] ; then
  mkdir -p ~/.mozbuild/moz-phab
  cd ~/.mozbuild/moz-phab
  curl -O https://raw.githubusercontent.com/mozilla-conduit/review/$(basename $(curl -sLo /dev/null -w '%{url_effective}' https://github.com/mozilla-conduit/review/releases/latest))/moz-phab
  chmod +x moz-phab
fi

# Install MOZ build requirement
sudo apt-get install cargo
#cargo install cbindgen

# Install watchman
WATCHMAN_PATH="$HOME/.mozbuild"
if [ ! -e $WATCHMAN_PATH/watchman ] ; then
  cd $WATCHMAN_PATH
  git clone https://github.com/facebook/watchman.git
  cd watchman/
  git checkout v4.9.0
  sudo apt-get install -y autoconf automake build-essential python-dev
  sudo apt-get install libssl-dev
  ./autogen.sh
  ./configure
  make
  sudo make install
  # For firefox
  git config core.fsmonitor /Users/dlee/Project/Firefox/source/.git/hooks/query-watchmanc
  mv .git/hooks/fsmonitor-watchman.sample .git/hooks/query-watchman
  echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
fi

# ZSH
OH_MY_ZSH_PATH="$HOME/.oh-my-zsh"
ZSH_PURE_THEM_PATH="$HOME/.zsh/pure"

if [ ! -e $FIREFOX_PROJECT_PATH/gecko ] ; then
  sudo apt-get install cargo
  sh -c "$(wget -O- https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
fi

# Pure THEME
# https://github.com/sindresorhus/pure
if [ ! -e $ZSH_PURE_THEM_PATH ] ; then
  mkdir -p ZSH_PURE_THEM_PATH
  git clone https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"
fi

# ZSH syntax highlighting
# https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md
ZSH_SYNTAX_HIGHLIGHTING_PATH="$HOME/.oh-my-zsh/plugins"
if [ ! -e $ZSH_SYNTAX_HIGHLIGHTING_PATH/zsh-syntax-highlighting ] ; then
  cd $ZSH_SYNTAX_HIGHLIGHTING_PATH
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
fi

# Dimi's Setup
DIMI_SETUP_PATH="$HOME/dimitools"
if [ ! -e $DIMI_SETUP_PATH ] ; then
  git clone https://github.com/DimiDL/DimiEnv $DIMI_SETUP_PATH
  cp $DIMI_SETUP_PATH/zsh/.zshrc $HOME
fi

TRY_PRESET_TARGET_PATH="$HOME/.mozbuild/try_presets.yml"
TRY_PRESET_SOURCE_PATH="$HOME/dimitools/moztools/try_presets.yml"
if [ ! -e $TRY_PRESET_TARGET_PATH ] ; then
  cp $TRY_PRESET_SOURCE_PATH $TRY_PRESET_TARGET_PATH
fi

SSH_CONFIG_TARGET_PATH="$HOME/.ssh/config"
SSH_CONFIG_SOURCE_PATH="$HOME/dimitools/moztools/ssh-config"
if [ ! -e $SSH_CONFIG_TARGET_PATH ] ; then
  cp $SSH_CONFIG_SOURCE_PATH $SSH_CONFIG_TARGET_PATH
fi
