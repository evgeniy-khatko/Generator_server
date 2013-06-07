#public void testDisplayBlackBox() {
#		//Enter any integer/decimal value for first edit-field, we are writing 10
#		solo.enterText(0, "");
#		solo.clickOnText("Login");
#		assertTrue(solo.searchText("qwerty"));
#	}
#
#
#<step from='Login' to='Login (input done)'>
#  <step_info locator='@pwd' index='0' action='enter' data='&quot;correct_pwd&quot;' eq_class='correct_credentials'/>
#</step>
#<step from='Info page' to='Login'>
#    <step_info locator='Handy Safe..' index='0' action='press'/>
#    <step_info locator='Handy Safe' action='exist'/>
#    <step_info locator='@pwd' action='exist'/>
#</step>
#
require '../generator/TestInfo'
require "rexml/document"
include REXML

def prepare(step_info)
  result = ''
  case
  when step_info.attributes["action"] == TestInfo::PRESS
    result += "solo.clickOnText(\"#{step_info.attributes["locator"]}\");\n"
  when step_info.attributes["action"] == TestInfo::LONG_PRESS
    result += "solo.clickLongOnText(\"#{step_info.attributes["locator"]}\");\n"
  when step_info.attributes["action"] == TestInfo::SWIPE_LEFT
    result += "solo.scrollToSide(21);\n"
  when step_info.attributes["action"] == TestInfo::SWIPE_RIGHT
    result += "solo.scrollToSide(22);\n"
  when step_info.attributes["action"] == TestInfo::SCROLL_UP
    result += "solo.scrollUp();\n"
  when step_info.attributes["action"] == TestInfo::SCROLL_DOWN
    result += "solo.scrollDown();\n"
  when step_info.attributes["action"] == TestInfo::EXIST
    result += "assertTrue(solo.searchText(\"#{step_info.attributes["locator"]}\"));\n"
  when step_info.attributes["action"] == TestInfo::ENTER
    result += "solo.clearEditText(#{step_info.attributes["index"]})\n"
    result += "solo.enterText(#{step_info.attributes["index"]},#{step_info.attributes["data"]});\n"
  when step_info.attributes["action"] == TestInfo::SELECT
    result += "// sould be implemented\n"
    result += "select_from_spinner(#{step_info.attributes["index"]}), #{step_info.attributes["data"]}\n"
  when step_info.attributes["action"] == TestInfo::CHECK
    result += "clickOnCheckBox(\"#{step_info.attributes["index"]}\")\n"
  when step_info.attributes["action"] == TestInfo::CHOOSE
    result += "clickOnRadioButton(\"#{step_info.attributes["index"]}\")\n"
  end
  if !step_info.attributes["internal_check"].nil?
    result += "// should be implemented\n"
    result += "#{step_info.attributes["internal_check"]}();\n"
  end
  result
end


out = ''
doc=Document.new File.open(ARGV[0])
XPath.each(doc, "//test"){|test|					
  name = test.attributes["name"]
  out += "\tpublic void #{name}() {\n"
  test.elements.each{ |step|
    out += "\t\t// #{step.attributes["from"]} => #{step.attributes["to"]}\n"
    step.elements.each{ |step_info|
      out += "#{prepare(step_info).split("\n").collect{ |s| "\t\t#{s}\n" }.join}"
    }
  }
  out += "\t}\n\n"
}
puts out

