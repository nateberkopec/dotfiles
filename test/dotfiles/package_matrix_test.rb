require "test_helper"

class PackageMatrixTest < Minitest::Test
  def test_matrix_defaults_to_empty
    matrix = Dotfiles::PackageMatrix.new({})

    assert_equal [], matrix.matrix
  end

  def test_brew_packages_default
    matrix = Dotfiles::PackageMatrix.new({})

    assert_equal [], matrix.brew_packages
  end

  def test_debian_packages_default
    matrix = Dotfiles::PackageMatrix.new({})

    assert_equal [], matrix.debian_packages
  end

  def test_matrix_reads_hash_entries
    matrix = Dotfiles::PackageMatrix.new(
      "packages" => {
        "fish" => {"brew" => "fish", "debian" => "fish"},
        "ripgrep" => {"brew" => "ripgrep", "debian" => ["ripgrep", "rg"]}
      }
    )

    assert_equal ["fish", "ripgrep"], matrix.brew_packages
    assert_equal ["fish", "ripgrep", "rg"], matrix.debian_packages
    assert_equal [["fish", "fish"], ["ripgrep", ["ripgrep", "rg"]]], matrix.matrix
  end

  def test_matrix_raises_when_entry_missing_values
    matrix = Dotfiles::PackageMatrix.new(
      "packages" => {
        "empty" => {"brew" => nil, "debian" => nil}
      }
    )

    assert_raises(ArgumentError) { matrix.matrix }
  end

  def test_matrix_reads_legacy_brew_packages
    matrix = Dotfiles::PackageMatrix.new(
      "brew" => {"packages" => ["jq", "rg"]}
    )

    assert_equal [["jq", nil], ["rg", nil]], matrix.matrix
  end
end
