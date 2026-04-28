from pybatfish.client.session import Session
from pybatfish.datamodel import *
from pybatfish.datamodel.answer import *
from pybatfish.datamodel.flow import *
import pandas as pd

# call this script with `python -i` and query interactive.
if __name__ == "__main__":
    pd.set_option("display.width", 300)
    pd.set_option("display.max_columns", 20)
    pd.set_option("display.max_rows", 200)

    bf = Session(host='localhost')
    bf.set_network('batfish-test-topology')

# bf.init_snapshot(path, name='snapshot-name', overwrite=True)

# # layer3
# ans = bf.q.edges(edgeType='layer3')
# ans.answer().frame()

# # layer1
# ans = bf.q.edges(edgeType='layer1')
# ans.answer().frame()

# # select edges by host name
# df = ans.answer().frame()
# df.loc[list(map(lambda d: d.hostname=='host11', df.Interface.values))]
