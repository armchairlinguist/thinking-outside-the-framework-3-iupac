#
# The basic data objects
#
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

  def to_s
    symbol
  end

  def atoms
    [Atom.new(self)]
  end

  def [](*neighbors)
    Moiety.new(self,*neighbors) { |m,i,x| m.atoms[0].bond(x[0]) if i > 0 }
  end

end

class Atom
  attr_reader :element
  attr_reader :bonds   # array of atoms to which this one is bonded.

  def initialize(e)
    @element = e
    @bonds = []
  end

  def to_s
    element.to_s
  end

  # Can bond one element to another more than once.
  def bond(other)
    raise "Can't bond an atom to itself." if self == other
    raise "Can't bond to any more atoms" if (self.saturated? || other.saturated?)
    @bonds << other
    other.bonds << self
    self
  end
  
  def saturated?
    valence = self.element.valence
    @bonds.length == valence
  end
  
  def atoms
    [self]
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
  def empirical_formula
    atoms.
      each_with_object(Hash.new(0)) { |a,counts| counts[a.element] += 1 }.
      map { |e,n| "#{e}#{n > 1 ? n : ''}"}.
      sort.
      join
  end

  def hydrated
    atoms.each { |a|
      atoms << H[a].atoms[0] while a.bonds.count < a.element.valence
    }
    self
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

# I'd like to do something clever with splats here, but this'll do for now.
def unbond(atom1,atom2)
  atom1.bonds.delete(atom2)
  atom2.bonds.delete(atom1)
  [atom1.bonds, atom2.bonds]
end

class Fixnum
  def of(&blk)
    (1..self).map(&blk)
  end
end

# I probably don't need this, but might be useful for visualizing.

class Moiety
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

#
# A few examples / test cases
#

Element.new("Hydrogen","H",  1.0, 1)
Element.new("Carbon",  "C", 12.0, 4,true)
Element.new("Nitrogen","N", 14.0, 3,true)
Element.new("Oxygen",  "O", 16.0, 2)
Element.new("Chlorine","Cl",35.5, 1)
Element.new("Silicon","Si",28.08,4, true)

water = O[H,H]
p water.mass
p water.empirical_formula

ethane = C[H,H,H,C[H,H,H]]
p ethane.mass
p ethane.empirical_formula

octane = chain(*8.of {C}).hydrated

cyclohexane = ring(*6.of {C}).hydrated

benzene = ring(*6.of {C}) {|m,i,x,l| l.bond(x[0]) if i.odd? }.hydrated
