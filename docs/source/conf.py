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
    raise RuntimeError('Cannot import fcio, please investigate.')

# generate docs from the installed source code, might differ from the code in the repo
# and is required for cython modules
sys.path.insert(0, os.path.abspath(os.path.dirname(inspect.getfile(fcio))))

project = 'fcio'
copyright = '2023, Simon Sailer'
author = 'Simon Sailer'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.napoleon',
    'sphinx.ext.viewcode',
    'sphinx.ext.autosummary',
    'sphinx_mdinclude'
]
napoleon_google_docstring = False
napoleon_use_param = False
napoleon_use_ivar = True
add_module_names = False

templates_path = ['_templates']
exclude_patterns = ['_build', '_templates']

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'furo'
html_static_path = ['_static']