if [ -z "$BOT_BASE_PATH" ]; then
  echo "BOT_BASE_PATH missing"
  exit 1
fi

gitterHook=""
slackHook=""
slackChannel="build-server-logs"

basePath="$BOT_BASE_PATH"
mainRepo="cdnjs"
webRepo="new-website"
hasLocalRepo=true
forceUpdateMeta=false
forceUpdateRepo=false

pushMetaOnGitHub=false

timeout=1200     #maximun execution time for a command, in second
nice=15
retryTimes=3     #retry limit for run_retry()

logFile='build.log'
logMode='clean' #append|clean
logPath=''      #if empty, log will be placed at the root of buildScript

path="/usr/local/bin:/usr/bin:/bin"
serverOwner="robocdnjs"
