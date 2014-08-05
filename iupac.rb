class Element
  attr_reader :name,:symbol,:mass,:valence,:skeletal
  def initialize(n,s,m,v,sk=false)
    @name = n
    @symbol = s
    @mass = m
    @valence = v
    @skeletal = sk
    Object.const_set(s,self)
  end
  def atoms
    [Atom.new(self)]
  end
  def [](*neighbors)
    Moiety.new(self,*neighbors) { |m,i,x| m.atoms[0].bond(x[0]) if i > 0 }
  end
  def to_s
    symbol
  end
end

Element.new("Hydrogen","H",  1.0, 1)
Element.new("Carbon",  "C", 12.0, 4,true)
Element.new("Nitrogen","N", 14.0, 3,true)
Element.new("Oxygen",  "O", 16.0, 2)
Element.new("Chlorine","Cl",35.5, 1)

class Atom
  attr_reader :element
  attr_reader :bonds   # array of atoms to which this one is bonded.
  def initialize(e)
    @element = e
    @bonds = []
  end
  def bond(other)
    @bonds << other
    other.bonds << self
    self
  end
  def atoms
    [self]
  end
  def to_s
    element.to_s
  end
end

class Moiety
  attr_reader :atoms
  def initialize(*moieties,&join)
    parts = moieties.map(&:atoms)
    @atoms = parts.flatten
    parts.each_with_index { |x,i| join[self,i,x] }
  end
  def mass
    atoms.map { |a| a.element.mass }.inject(&:+)
  end
  def hydrated
    atoms.each { |a| atoms << H[a].atoms[0] while a.bonds.count < a.element.valence }
    self
  end
  def emperical_formula
    atoms.
      each_with_object(Hash.new(0)) { |a,counts| counts[a.element] += 1 }.
      map { |e,n| "#{e}#{n > 1 ? n : ''}"}.
      sort.
      join
  end
  def dot(file_name)
    File.open(file_name,'w') { |f|
      f.puts 'graph "" {'
      index = {}
      atoms.
        flat_map { |a| [a,*a.bonds] }.
        uniq.
        each_with_index { |a,i|
          index[a] = i
          f.puts "    a#{i} [label=#{a.element}];"
          a.bonds.each { |b| f.puts "      a#{i} -- a#{index[b]};" if index[b] }
        }
      f.puts '}'
    }
  end
end

def chain(*moieties,&join)
  last = nil
  Moiety.new(*moieties) { |m,i,x|
    x[0].bond last[0] if last
    join[m,i,x,last[0]] if last && join
    last = x
  }
end

def ring(*moieties,&join)
  chain(*moieties) { |m,i,x,l|
    x[0].bond m.atoms[0] if i == moieties.length-1
    join[m,i,x,l] if join
  }
end

class Fixnum
  def of(&blk)
    (1..self).map(&blk)
  end
end

p O[H,H].mass
p O[H,H].emperical_formula

ethane = C[H,H,H,C[H,H,H]]
p ethane.mass
p ethane.emperical_formula
ethane.dot('ethane.dot')

chain(*8.of {C}).hydrated.dot('octane.dot')
ring(*6.of {C}).hydrated.dot('cyclohexane.dot')
ring(*6.of {C}) {|m,i,x,l| l.bond(x[0]) if i.odd? }.hydrated.dot('benzene.dot')
