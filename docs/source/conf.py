# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

import os
import sys
import inspect

try:
    import fcio
except ImportError:
    raise RuntimeError('Cannot import fcio, which is required to parse the docstrings from cython code.')

# generate docs from the installed source code, might differ from the code in the repo
# and is required for cython modules
sys.path.insert(0, os.path.abspath(os.path.dirname(inspect.getfile(fcio))))

project = 'fcio'
copyright = '2025'
author = 'FlashCam'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.autosummary',
    'sphinx.ext.napoleon',
    'sphinx.ext.viewcode',
    'sphinx_mdinclude',
    'sphinx_autodoc_typehints',
    'sphinx_rtd_theme'
]
napoleon_google_docstring = False
napoleon_use_param = False
napoleon_use_ivar = True
add_module_names = False

templates_path = ['_templates']
exclude_patterns = ['_build', '_templates']

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_title = 'fcio-py'
html_static_path = ['_static']
html_theme = 'sphinx_book_theme'
html_theme_options = {
    "repository_url": "https://github.com/FlashCam/fcio-py",
    "use_repository_button": True,
    "show_navbar_depth": 3,
    "show_toc_level": 2,
}
html_context = {
  'display_github': True,
  'github_user': 'FlashCam',
  'github_repo': 'fcio-py',
  'github_version': 'main/docs/source/',
}
