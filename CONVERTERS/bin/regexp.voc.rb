CASE_LINE=Regexp.new('\s{2}(.+):$')
INTERACTION_LINE=Regexp.new('\s{4}(.+)$')

TRANSITION_TYPE=Regexp.new('^([^;]+);')
TRANSITION_CONDITION=Regexp.new('condition\(([^);]+)\)')
TRANSITION_ACTION=Regexp.new('action\(([^);]+)\)')
TRANSITION_INTERNAL=Regexp.new('internal\(([^);]+)\)')
TRANSITION_CHANCE=Regexp.new('chance\(([^);]+)\)')
TRANSITION_CASE=Regexp.new('Case\s\d+')

# MAIN-------->
OPEN_LINK_IN=Regexp.new('^Open (.+) in .+$')
SET_P_STATE=Regexp.new('^Set (.+) state to (.+)$')
SET_P_STATES=Regexp.new('^Set .+, ([^,]+) state to ([^,]+)$')
SHOW_PANEL=Regexp.new('^Show (.+)$')
HIDE_PANEL=Regexp.new('^Hide (.+)$')
TOGGLE_VISIBILITY=Regexp.new('^Toggle Visibility for (.+)$')

WAIT=Regexp.new('^Wait \d+ ms$')
SET_TEXT=Regexp.new('^Set text.+$')
SET_IS_CHECKED=Regexp.new('^Set is checked of .+$')
SET_SELECTED_OPT=Regexp.new('^Set selected option of .+$')
SET_VAR_VAL=Regexp.new('^Set value of .+$')
CLOSE_CUR_W=Regexp.new('^Close Current Window')
MOVE_PANEL=Regexp.new('^Move .+ to .+$')
BRING_TO_FRONT_PANEL=Regexp.new('^Bring (.+) to Front$')
SCROLL_TO=Regexp.new('^Scroll to .+$')
ENABLE_W=Regexp.new('^Enable .+$')
DISABLE_W=Regexp.new('^Disable .+$')
SET_TO_SELECTED=Regexp.new('^Set .+ to Selected$')
SET_TO_DEFAULT=Regexp.new('^Set .+ to Default$')
SET_FOCUS=Regexp.new('^Set Focus on .+$')
EXPAND=Regexp.new('^Expand .+') 
COLLAPSE=Regexp.new('^Collapse .+') 

# Set text on widget pwd equal to "qwerty"
# Set is checked of 333 equal to true
# Set selected option of 111111 equal to "1"
INPUT=Regexp.new('\s+Set text on widget (.+) equal to (.+)$')
SELECT=Regexp.new('\s+Set selected option of (.+) equal to (.+)$')
CHECK=Regexp.new('\s+Set is checked of (.+) equal to (.+)$')
CHOOSE=Regexp.new('\s+Set is checked of (.+) equal to (.+)$')
