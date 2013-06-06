#public void testDisplayBlackBox() {
#		//Enter any integer/decimal value for first edit-field, we are writing 10
#		solo.enterText(0, "");
#		solo.clickOnText("Login");
#		assertTrue(solo.searchText("qwerty"));
#	}
require '../generator/TestInfo'
include REXML

out = ''
doc=Document.new getXmlFile(ARGV[0])
XPath.each(doc, "//test"){|test|					
  name = test.attributes["name"]
  out += "\tpublic void #{name}() {\n"
  XPath.each(test, "//step_info"){ |step|
    prepare_step(out,step)
  }
  out += "\t}\n\n"
}

def prepare_step(rexml_object)

end

