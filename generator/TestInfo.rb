class TestInfo 
  START = 'start_application'
  SELECT = 'select'
  ENTER = 'enter'
  CHECK = 'check'
  PRESS = 'press'
  LONG_PRESS = 'long_press'
  SWIPE_LEFT = 'swipe_left'
  SWIPE_RIGHT = 'swipe_right'
  SCROLL_DOWN = 'scroll_down'
  SCROLL_UP = 'scroll_up'
  EXIST = 'exist'
  DETERMINISTIC = [PRESS, LONG_PRESS, SWIPE_LEFT, SWIPE_RIGHT, SCROLL_DOWN, SCROLL_UP, START]
  VARIOUS = [SELECT, ENTER, CHECK]
  EXPECTED = [EXIST]
  DEFAULT = PRESS

	attr_accessor :id, :parent_id, :locator, :action, :eq_class, :data, :internal_check, :index

	def initialize(id, parent_id)
    @parent_id = parent_id
    @id = id
    @locator, @action, @eq_class, @data, @internal_check = ''
    @index = nil
    self.class.add(self)
	end

  def self.fnd_by_id(id)
    @objects.select{ |el| el.id == id }
  end

  def self.fnd_by_parent(parent_id)
    @objects.select{ |el| el.parent_id == parent_id }
  end

  def action= a
    @action = a
    return if EXPECTED.include? a
    page_elements = self.class.fnd_by_parent(self.parent_id)
    page_elements_with_same_action = page_elements.select{ |o| !EXPECTED.include?(o.action) and o.action == a and o.id != self.id } 
    @index = page_elements_with_same_action.length
  end

  def deterministic?
    DETERMINISTIC.include? self.action
  end

  def various?
    VARIOUS.include? self.action
  end

  def expected?
    EXPECTED.include? self.action
  end

  def self.objects
    @objects
  end

  def to_action
    "#{self.locator}=#{self.data.gsub(/"/,"'")}"
  end

  private
  @objects = []

  def self.add(obj)
    @objects << obj
  end
end
